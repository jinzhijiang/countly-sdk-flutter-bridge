### Initializing or Updating the iOS SDK

The iOS SDK version used by this SDK is managed through the init-ios-sdk.sh script.
Run the script anytime you want to initialize, update, or switch the Countly iOS SDK version.

```bash
./scripts/init-ios-sdk.sh
```

If it gives permission error

```bash
chmod +x scripts/init-ios-sdk.sh
```

Then try to run again.

#### Changing the iOS SDK Version

The Countly iOS SDK is included as a Git submodule.
To update its version, open VS Code -> Source Control and switch to the desired commit or tag directly from the submodule section.
