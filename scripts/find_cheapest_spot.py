#!/usr/bin/env python3
"""
Find the cheapest AWS EC2 spot instance in European regions.
"""

import boto3
from datetime import datetime, timedelta
from collections import defaultdict
import json
import argparse
import urllib.request
import sys

# Global flag to suppress non-JSON output
_quiet_mode = False

# European AWS regions
EU_REGIONS = [
    'eu-north-1',     # Stockholm
    'eu-west-1',      # Ireland
    'eu-west-2',      # London
    'eu-west-3',      # Paris
    'eu-central-1',   # Frankfurt
    'eu-central-2',   # Zurich
    'eu-south-1',     # Milan
    'eu-south-2',     # Spain
]

# Interruption frequency ranges (index 0-4 maps to these labels)
INTERRUPTION_RANGES = ['<5%', '5-10%', '10-15%', '15-20%', '>20%']

# Cache for spot advisor data
_spot_advisor_cache = None


def get_spot_advisor_data():
    """
    Fetch spot advisor data from AWS S3 endpoint.
    Returns interruption frequency data for all instance types by region.
    Data is cached for the session.
    """
    global _spot_advisor_cache

    if _spot_advisor_cache is not None:
        return _spot_advisor_cache

    try:
        url = "https://spot-bid-advisor.s3.amazonaws.com/spot-advisor-data.json"
        with urllib.request.urlopen(url, timeout=10) as response:
            data = json.loads(response.read().decode('utf-8'))
            _spot_advisor_cache = data
            return data
    except Exception as e:
        if not _quiet_mode:
            print(f"Warning: Could not fetch spot advisor data: {e}", file=sys.stderr)
        return None


def get_interruption_rate(spot_advisor_data, region, instance_type):
    """
    Get interruption frequency for a specific instance type in a region.
    Returns a dict with 'range' (e.g., '<5%'), 'index' (0-4), and 'max_percent' (5, 10, 15, 20, 100).
    """
    if not spot_advisor_data:
        return None

    try:
        # Data is organized as: spot_advisor -> region -> Linux/Windows -> instance_type -> {r, s}
        region_data = spot_advisor_data.get('spot_advisor', {}).get(region, {})
        linux_data = region_data.get('Linux', {})
        instance_data = linux_data.get(instance_type)

        if instance_data:
            # 'r' is the range index (0-4): 0=<5%, 1=5-10%, 2=10-15%, 3=15-20%, 4=>20%
            range_idx = instance_data.get('r', 4)  # Default to highest if missing
            range_label = INTERRUPTION_RANGES[range_idx] if range_idx < len(INTERRUPTION_RANGES) else '>20%'

            # Map index to max percent for filtering (0->5, 1->10, 2->15, 3->20, 4->100)
            max_percent_map = {0: 5, 1: 10, 2: 15, 3: 20, 4: 100}
            max_percent = max_percent_map.get(range_idx, 100)

            return {
                'range': range_label,
                'index': range_idx,
                'max_percent': max_percent
            }
    except Exception:
        pass

    return None


def get_instance_types_with_specs(region, min_vcpu, min_memory_gb, min_storage_gb=None):
    """
    Get all instance types in a region that meet minimum vCPU, memory, and optionally storage requirements.
    Returns a dictionary with instance type details including storage info.
    """
    ec2_client = boto3.client('ec2', region_name=region)

    matching_instances = {}

    try:
        # Describe all instance types (can't use >= in filters, so we filter manually)
        paginator = ec2_client.get_paginator('describe_instance_types')

        for page in paginator.paginate():
            for instance_type in page['InstanceTypes']:
                instance_name = instance_type['InstanceType']

                # Get vCPU and memory info
                actual_vcpu = instance_type['VCpuInfo']['DefaultVCpus']
                actual_memory_mib = instance_type['MemoryInfo']['SizeInMiB']
                actual_memory_gb = actual_memory_mib / 1024

                # Filter by minimum vCPU and memory
                if actual_vcpu < min_vcpu or actual_memory_gb < min_memory_gb:
                    continue

                # Extract ephemeral storage info
                storage_info = "EBS only"
                storage_gb = 0

                if 'InstanceStorageInfo' in instance_type:
                    storage = instance_type['InstanceStorageInfo']
                    if 'TotalSizeInGB' in storage:
                        storage_gb = storage['TotalSizeInGB']
                        disk_type = storage.get('Disks', [{}])[0].get('Type', 'Unknown') if storage.get('Disks') else 'Unknown'
                        storage_info = f"{storage_gb}GB ({disk_type})"

                # Filter by minimum storage if specified
                if min_storage_gb is not None:
                    if storage_gb < min_storage_gb:
                        continue  # Skip instances that don't meet storage requirement

                matching_instances[instance_name] = {
                    'storage': storage_info,
                    'vcpu': actual_vcpu,
                    'memory_gb': int(actual_memory_gb)
                }

    except Exception as e:
        if not _quiet_mode:
            print(f"Error fetching instance types for {region}: {e}", file=sys.stderr)

    return matching_instances


def get_spot_placement_scores(instance_types, target_capacity=1):
    """
    Get Spot placement scores for given instance types across all regions.
    Returns a dictionary mapping region -> score (1-10).

    Note: AWS requires at least 3 instance types for meaningful scores.
    """
    # Use a central region to make the API call (it returns scores for all regions)
    ec2_client = boto3.client('ec2', region_name='eu-west-1')

    scores = {}

    try:
        # Need at least 3 instance types for meaningful scores
        instance_types_list = list(instance_types)[:100]  # API limit

        if len(instance_types_list) < 3:
            print(f"  Warning: Only {len(instance_types_list)} instance types found. Placement scores work best with 3+ types.")

        paginator = ec2_client.get_paginator('get_spot_placement_scores')

        for page in paginator.paginate(
            InstanceTypes=instance_types_list,
            TargetCapacity=target_capacity,
            RegionNames=EU_REGIONS,
            SingleAvailabilityZone=False
        ):
            for score_item in page.get('SpotPlacementScores', []):
                region = score_item.get('Region')
                score = score_item.get('Score')
                if region and score is not None:
                    scores[region] = score

    except Exception as e:
        if not _quiet_mode:
            print(f"Error fetching placement scores: {e}", file=sys.stderr)

    return scores


def get_spot_prices(region, instance_types_info):
    """
    Get spot prices with 24-hour history for given instance types in a region.
    Calculates current, average, min, and max prices.
    """
    ec2_client = boto3.client('ec2', region_name=region)

    spot_prices = {}
    price_history = defaultdict(list)  # Store all prices for each instance/AZ
    instance_types_list = list(instance_types_info.keys())

    try:
        # Get spot price history for the last 24 hours
        response = ec2_client.describe_spot_price_history(
            InstanceTypes=instance_types_list,
            ProductDescriptions=['Linux/UNIX'],
            StartTime=datetime.now() - timedelta(hours=24),
        )

        # Collect all price data points
        for item in response['SpotPriceHistory']:
            instance_type = item['InstanceType']
            az = item['AvailabilityZone']
            price = float(item['SpotPrice'])
            timestamp = item['Timestamp']

            key = f"{instance_type}:{az}"
            price_history[key].append({
                'price': price,
                'timestamp': timestamp
            })

        # Calculate statistics for each instance/AZ combination
        for key, history in price_history.items():
            if not history:
                continue

            # Sort by timestamp to get the most recent
            history.sort(key=lambda x: x['timestamp'], reverse=True)

            prices = [h['price'] for h in history]
            most_recent = history[0]

            instance_type, az = key.split(':')

            # Calculate statistics
            current_price = most_recent['price']
            avg_price = sum(prices) / len(prices)
            min_price = min(prices)
            max_price = max(prices)

            # Calculate volatility as percentage difference between min and max
            volatility_pct = ((max_price - min_price) / avg_price * 100) if avg_price > 0 else 0

            # Convert timestamp to ISO string for JSON serialization
            timestamp_str = most_recent['timestamp'].isoformat() if hasattr(most_recent['timestamp'], 'isoformat') else str(most_recent['timestamp'])

            spot_prices[key] = {
                'instance_type': instance_type,
                'region': region,
                'availability_zone': az,
                'price': current_price,
                'avg_24h': avg_price,
                'min_24h': min_price,
                'max_24h': max_price,
                'volatility_pct': volatility_pct,
                'data_points': len(prices),
                'storage': instance_types_info[instance_type]['storage'],
                'vcpu': instance_types_info[instance_type]['vcpu'],
                'memory_gb': instance_types_info[instance_type]['memory_gb'],
                'timestamp': timestamp_str
            }

    except Exception as e:
        if not _quiet_mode:
            print(f"Error fetching spot prices for {region}: {e}", file=sys.stderr)

    return list(spot_prices.values())


def find_cheapest_spot_instance(vcpu, memory_gb, min_storage_gb=None, preferred_region=None,
                                 json_output=False, min_placement_score=None, max_interruption=None):
    """
    Find the cheapest spot instance across all European regions.
    Optionally highlights results for a preferred region.
    Supports filtering by minimum placement score and maximum interruption rate.
    """
    global _quiet_mode
    _quiet_mode = json_output

    def log(msg):
        if not json_output:
            print(msg)

    storage_msg = f" and at least {min_storage_gb}GB ephemeral storage" if min_storage_gb else ""
    preferred_msg = f" (preferred region: {preferred_region})" if preferred_region else ""
    filter_msgs = []
    if min_placement_score:
        filter_msgs.append(f"placement score >= {min_placement_score}")
    if max_interruption:
        filter_msgs.append(f"interruption <= {max_interruption}%")
    filter_msg = f" [filters: {', '.join(filter_msgs)}]" if filter_msgs else ""
    log(f"Searching for cheapest spot instance with at least {vcpu} vCPUs, {memory_gb}GB RAM{storage_msg} in European regions{preferred_msg}{filter_msg}...\n")

    all_prices = []
    all_instance_types = set()

    for region in EU_REGIONS:
        log(f"Checking {region}...")

        # Get instance types that match our specs
        instance_types = get_instance_types_with_specs(region, vcpu, memory_gb, min_storage_gb)

        if not instance_types:
            log(f"  No matching instance types found in {region}")
            continue

        log(f"  Found {len(instance_types)} matching instance types")
        all_instance_types.update(instance_types.keys())

        # Get spot prices for these instance types
        prices = get_spot_prices(region, instance_types)

        if prices:
            log(f"  Found {len(prices)} spot price entries")
            all_prices.extend(prices)
        else:
            log(f"  No spot prices available")

    if not all_prices:
        if json_output:
            print(json.dumps({"error": "No spot prices found"}, indent=2))
        else:
            print("\nNo spot prices found!")
        return

    # Get placement scores for all instance types found
    log("\nFetching Spot placement scores...")
    placement_scores = get_spot_placement_scores(all_instance_types)

    if placement_scores:
        log(f"  Retrieved placement scores for {len(placement_scores)} regions")
        # Add placement score to each price entry
        for price_info in all_prices:
            price_info['placement_score'] = placement_scores.get(price_info['region'], 'N/A')
    else:
        log("  Could not retrieve placement scores")
        for price_info in all_prices:
            price_info['placement_score'] = 'N/A'

    # Get interruption frequency data
    log("\nFetching Spot interruption frequency data...")
    spot_advisor_data = get_spot_advisor_data()

    if spot_advisor_data:
        log("  Retrieved interruption frequency data")
        for price_info in all_prices:
            interruption = get_interruption_rate(
                spot_advisor_data,
                price_info['region'],
                price_info['instance_type']
            )
            if interruption:
                price_info['interruption_frequency'] = interruption['range']
                price_info['interruption_max_percent'] = interruption['max_percent']
            else:
                price_info['interruption_frequency'] = 'N/A'
                price_info['interruption_max_percent'] = 100
    else:
        log("  Could not retrieve interruption frequency data")
        for price_info in all_prices:
            price_info['interruption_frequency'] = 'N/A'
            price_info['interruption_max_percent'] = 100

    # Apply filters
    filtered_prices = all_prices

    if min_placement_score:
        before_count = len(filtered_prices)
        filtered_prices = [
            p for p in filtered_prices
            if isinstance(p['placement_score'], int) and p['placement_score'] >= min_placement_score
        ]
        log(f"\nFiltered by placement score >= {min_placement_score}: {before_count} -> {len(filtered_prices)} instances")

    if max_interruption:
        before_count = len(filtered_prices)
        filtered_prices = [
            p for p in filtered_prices
            if p['interruption_max_percent'] <= max_interruption
        ]
        log(f"Filtered by interruption <= {max_interruption}%: {before_count} -> {len(filtered_prices)} instances")

    if not filtered_prices:
        if json_output:
            print(json.dumps({"error": "No instances match the specified filters"}, indent=2))
        else:
            print("\nNo instances match the specified filters!")
        return

    # Sort by price
    filtered_prices.sort(key=lambda x: x['price'])

    # Prepare results
    cheapest = filtered_prices[0]
    preferred_prices = [p for p in filtered_prices if p['region'] == preferred_region] if preferred_region else []
    cheapest_preferred = preferred_prices[0] if preferred_prices else None

    # JSON output mode
    if json_output:
        def format_instance(price_info):
            """Format instance info for JSON output."""
            return {
                "instance_type": price_info['instance_type'],
                "vcpu": price_info['vcpu'],
                "memory_gb": price_info['memory_gb'],
                "region": price_info['region'],
                "availability_zone": price_info['availability_zone'],
                "placement_score": price_info['placement_score'],
                "interruption_frequency": price_info['interruption_frequency'],
                "ephemeral_storage": price_info['storage'],
                "pricing": {
                    "current": {
                        "hourly": round(price_info['price'], 4),
                        "daily": round(price_info['price'] * 24, 2),
                        "monthly": round(price_info['price'] * 24 * 30, 2)
                    },
                    "avg_24h": {
                        "hourly": round(price_info['avg_24h'], 4),
                        "daily": round(price_info['avg_24h'] * 24, 2),
                        "monthly": round(price_info['avg_24h'] * 24 * 30, 2)
                    },
                    "min_24h": round(price_info['min_24h'], 4),
                    "max_24h": round(price_info['max_24h'], 4),
                    "volatility_pct": round(price_info['volatility_pct'], 1)
                },
                "last_updated": price_info['timestamp'],
                "data_points": price_info['data_points']
            }

        result = {
            "cheapest_overall": format_instance(cheapest),
            "top_10_all_regions": [format_instance(p) for p in filtered_prices[:10]]
        }

        # Include applied filters in output
        if min_placement_score or max_interruption:
            result["filters"] = {}
            if min_placement_score:
                result["filters"]["min_placement_score"] = min_placement_score
            if max_interruption:
                result["filters"]["max_interruption_percent"] = max_interruption

        if preferred_region:
            result["preferred_region"] = preferred_region
            if cheapest_preferred:
                result["cheapest_in_preferred_region"] = format_instance(cheapest_preferred)
                result["top_10_preferred_region"] = [format_instance(p) for p in preferred_prices[:10]]
                if cheapest_preferred['price'] != cheapest['price']:
                    diff = cheapest_preferred['price'] - cheapest['price']
                    result["preferred_vs_cheapest"] = {
                        "difference_hourly": round(diff, 4),
                        "difference_pct": round((diff / cheapest['price']) * 100, 1)
                    }
            else:
                result["cheapest_in_preferred_region"] = None
                result["top_10_preferred_region"] = []

        print(json.dumps(result, indent=2))
        return

    # Text output mode
    def print_instance_list(prices, title, count=10):
        """Helper to print a list of instances."""
        print("\n" + "="*100)
        print(title)
        print("="*100)

        for i, price_info in enumerate(prices[:count], 1):
            current = price_info['price']
            avg = price_info['avg_24h']
            min_price = price_info['min_24h']
            max_price = price_info['max_24h']
            volatility = price_info['volatility_pct']
            score = price_info['placement_score']
            score_str = f"{score}/10" if isinstance(score, int) else score
            interruption = price_info['interruption_frequency']

            print(f"\n{i}. Current: ${current:.4f}/hour | ${current*24:.2f}/day | ${current*24*30:.2f}/month")
            print(f"   24h Average: ${avg:.4f}/hour | ${avg*24:.2f}/day | ${avg*24*30:.2f}/month")
            print(f"   24h Range: ${min_price:.4f} - ${max_price:.4f} (volatility: {volatility:.1f}%)")
            print(f"   Instance Type: {price_info['instance_type']}")
            print(f"   Specs: {price_info['vcpu']} vCPUs, {price_info['memory_gb']}GB RAM")
            print(f"   Region: {price_info['region']} (Placement Score: {score_str}, Interruption: {interruption})")
            print(f"   Availability Zone: {price_info['availability_zone']}")
            print(f"   Ephemeral Storage: {price_info['storage']}")
            print(f"   Last Updated: {price_info['timestamp']} ({price_info['data_points']} data points)")

    def print_cheapest(price_info, title):
        """Helper to print the cheapest option summary."""
        score = price_info['placement_score']
        score_str = f"{score}/10" if isinstance(score, int) else score
        interruption = price_info['interruption_frequency']

        print("\n" + "="*100)
        print(title)
        print("="*100)
        print(f"Instance Type: {price_info['instance_type']}")
        print(f"Specs: {price_info['vcpu']} vCPUs, {price_info['memory_gb']}GB RAM")
        print(f"\nCurrent Price: ${price_info['price']:.4f}/hour | ${price_info['price']*24:.2f}/day | ${price_info['price']*24*30:.2f}/month")
        print(f"24h Average: ${price_info['avg_24h']:.4f}/hour | ${price_info['avg_24h']*24:.2f}/day | ${price_info['avg_24h']*24*30:.2f}/month")
        print(f"24h Range: ${price_info['min_24h']:.4f} - ${price_info['max_24h']:.4f} (volatility: {price_info['volatility_pct']:.1f}%)")
        print(f"\nRegion: {price_info['region']}")
        print(f"Availability Zone: {price_info['availability_zone']}")
        print(f"Placement Score: {score_str}")
        print(f"Interruption Frequency: {interruption}")
        print(f"Ephemeral Storage: {price_info['storage']}")
        print(f"Last Updated: {price_info['timestamp']}")

    # Display results for all regions
    print_instance_list(filtered_prices, "TOP 10 CHEAPEST SPOT INSTANCES (ALL REGIONS)")
    print_cheapest(cheapest, "CHEAPEST OPTION (ALL REGIONS)")

    # If preferred region specified, also show results for that region
    if preferred_region:
        if preferred_prices:
            print_instance_list(preferred_prices, f"TOP 10 CHEAPEST SPOT INSTANCES IN {preferred_region.upper()}")
            print_cheapest(cheapest_preferred, f"CHEAPEST OPTION IN {preferred_region.upper()}")

            # Show price comparison
            if cheapest_preferred['price'] != cheapest['price']:
                diff = cheapest_preferred['price'] - cheapest['price']
                diff_pct = (diff / cheapest['price']) * 100
                print(f"\nNote: Preferred region is ${diff:.4f}/hour ({diff_pct:.1f}%) more expensive than the cheapest option.")
        else:
            print(f"\nNo spot prices found in preferred region {preferred_region}")


def parse_arguments():
    """
    Parse command-line arguments.
    """
    parser = argparse.ArgumentParser(
        description='Find the cheapest AWS EC2 spot instance in European regions.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  %(prog)s -c 4 -m 8
  %(prog)s -c 2 -m 4 -r eu-west-1
  %(prog)s --cpu 8 --memory 16 --preferred-region eu-central-1
  %(prog)s -c 4 -m 8 -s 150
  %(prog)s -c 8 -m 16 -s 300 -r eu-north-1
  %(prog)s -c 4 -m 8 -j                          # JSON output
  %(prog)s -c 4 -m 8 -r eu-west-1 --json         # JSON with preferred region
  %(prog)s -c 4 -m 8 --min-score 7               # Only instances with placement score >= 7
  %(prog)s -c 4 -m 8 --max-interruption 10       # Only instances with interruption <= 10%%
  %(prog)s -c 4 -m 8 -p 8 -i 5 -j                # Combined filters with JSON output
        '''
    )

    parser.add_argument(
        '-c', '--cpu',
        type=int,
        default=4,
        help='Number of vCPUs (default: 4)'
    )

    parser.add_argument(
        '-m', '--memory',
        type=int,
        default=8,
        help='Memory in GB (default: 8)'
    )

    parser.add_argument(
        '-s', '--storage',
        type=int,
        default=None,
        help='Minimum ephemeral storage in GB (optional, filters for instances with at least this much storage)'
    )

    parser.add_argument(
        '-r', '--preferred-region',
        type=str,
        default=None,
        choices=EU_REGIONS,
        help='Preferred region to highlight in results (e.g., eu-west-1)'
    )

    parser.add_argument(
        '-j', '--json',
        action='store_true',
        help='Output results as JSON (only final results, no progress output)'
    )

    parser.add_argument(
        '-p', '--min-score',
        type=int,
        default=None,
        choices=range(1, 11),
        metavar='1-10',
        help='Minimum placement score (1-10, higher = more likely to succeed)'
    )

    parser.add_argument(
        '-i', '--max-interruption',
        type=int,
        default=None,
        choices=[5, 10, 15, 20],
        metavar='PERCENT',
        help='Maximum interruption frequency (5, 10, 15, or 20 percent)'
    )

    return parser.parse_args()


if __name__ == '__main__':
    try:
        args = parse_arguments()
        find_cheapest_spot_instance(
            args.cpu,
            args.memory,
            args.storage,
            args.preferred_region,
            args.json,
            args.min_score,
            args.max_interruption
        )
    except Exception as e:
        if hasattr(args, 'json') and args.json:
            print(json.dumps({"error": str(e)}, indent=2))
        else:
            print(f"Error: {e}")
            print("\nMake sure you have:")
            print("1. boto3 installed: pip install boto3")
            print("2. AWS credentials configured: aws configure")
