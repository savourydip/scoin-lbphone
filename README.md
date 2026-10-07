# sCoin Phone App

A custom Phone app that displays the player's sCoin cryptocurrency balance from the `ra_boosting_user_settings` database table.

## Features

- 💰 Real-time sCoin balance display
- 🔄 Refresh button to update balance
- 🌓 Automatic dark/light mode support
- 📱 Clean, modern UI design
- ⚡ Smooth animations

## Requirements

- LB Phone (v1.5.0 or higher) or SD Phone
- QBX Core (qbx_core)
- oxmysql
- `ra_boosting_user_settings` table in your database

## Installation

1. **Place the resource** in your server's `resources` folder:
   ```
   resources/
   └── scoin-lbphone/
   ```

2. **Add to server.cfg**:
   ```cfg
   ensure scoin-lbphone
   ```
   
   ⚠️ **IMPORTANT**: Make sure this line comes AFTER `ensure lb-phone` in your server.cfg!

3. **Customize the app icons** (optional):
   - Open `client.lua`
   - Replace the placeholder URLs with your own icon images:
     ```lua
     images = {'https://your-icon-url.png'},
     icon = 'https://your-icon-url.png'
     ```

4. **Restart your server** or run:
   ```
   ensure scoin-lbphone
   ```

## How It Works

1. Players can download the "sCoin" app from the LB Phone app store
2. Opening the app shows their current sCoin balance
3. The balance is fetched from the `ra_boosting_user_settings` table using their `citizenid`
4. Players can click "Refresh Balance" to update their balance

## Database Structure

The app expects the following table structure:

```sql
CREATE TABLE IF NOT EXISTS `ra_boosting_user_settings` (
  `player_identifier` varchar(50) NOT NULL,
  `crypto` int(11) DEFAULT 0,
  PRIMARY KEY (`player_identifier`)
);
```

## Configuration

### Change App Name
Edit `client.lua`:
```lua
name = 'Your Custom Name',
description = 'Your custom description',
```

### Change Default App Status
To make the app installed by default (no download required):
```lua
defaultApp = true,
```

### Change App Price
To charge players for downloading the app:
```lua
price = 500, -- Price in game currency
```

## Troubleshooting

### App not showing in phone
- Make sure `scoin-lbphone` starts AFTER `lb-phone` in your server.cfg
- Check server console for errors
- Restart both lb-phone and scoin-lbphone

### Balance shows as 0
- Verify the player has a row in `ra_boosting_user_settings` table
- Check that the `player_identifier` column matches the player's `citizenid`
- Look for errors in server console (enable debug prints in server.lua if needed)

### Dark mode not working
- LB Phone automatically handles dark/light mode
- The app will match the phone's theme setting

## Support

For issues or questions, check:
- Server console for error messages
- Database to verify player records exist
- LB Phone documentation: https://docs.lbscripts.com/phone/

## Credits

Created for use with LB Phone by lbscripts.com
