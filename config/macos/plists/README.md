# Shared MacOS app settings

MacOS apps normally use the [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults) system to persist user settings.

UserDefaults uses `.plist` files stored in `~/Library/Preferences` for this purpose. Interacting directly with these files is tricky as they're loaded into RAM and dumped again eg. when quitting apps. Linking therefore doesn't work. The correct way to interact with this database is to use the `defaults` cli tool.

The `.plists` in this folder are created using the same names used in `~/Library/Preferences` folder.

```sh
# Export Alt-Tab settings and store here
defaults export com.lwouis.alt-tab-macos ~/.shell-config/config/macos/plists/com.lwouis.alt-tab-macos.plist

# Import Alt-Tab settings from here to the user's database
defaults import com.lwouis.alt-tab-macos ~/.shell-config/config/macos/plists/com.lwouis.alt-tab-macos.plist
```

