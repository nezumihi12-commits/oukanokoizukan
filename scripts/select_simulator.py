import json
import sys

devices = json.load(open(sys.argv[1]))['devices']
for runtime, items in sorted(devices.items(), reverse=True):
    if 'iOS' not in runtime:
        continue
    for item in items:
        if item.get('isAvailable') and item['name'].startswith('iPhone'):
            print('SIMULATOR_ID=' + item['udid'])
            sys.exit(0)
raise SystemExit('No available iPhone simulator. Check the macOS runner Xcode installation.')
