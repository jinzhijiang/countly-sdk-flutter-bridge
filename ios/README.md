### Initializing or Updating the iOS SDK

The iOS SDK version is managed through `scripts/config/sdk_versions.txt`.
Run the sync script to initialize, update, or switch all SDK versions including iOS:

```bash
./scripts/sync-sdk-versions.sh
```

If it gives permission error

```bash
chmod +x scripts/sync-sdk-versions.sh
```

Then try to run again.

#### Changing the iOS SDK Version

Update `ios_sdk_version` in `scripts/config/sdk_versions.txt`, then run `./scripts/sync-sdk-versions.sh`.
The Countly iOS SDK is included as a Git submodule and will be checked out at the specified tag.
