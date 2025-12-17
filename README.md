# RingMenu Reborn

A circular action bar addon for WoW Classic Era (1.15.x) that can be summoned with a keybind.

![RingMenu](http://i.imgur.com/DmDWVaA.png)

RingMenu Reborn is a modernized fork of the original RingMenu addon by jsb, updated to work with WoW Classic Era 1.15.x (2025).

## Features

- Circular action bar that appears at your cursor position
- Multiple ring configurations with individual keybinds
- Customizable number of buttons (1-24)
- Adjustable radius and rotation angle
- Backdrop color customization with opacity
- Close on click option
- Masque support for button skinning

## Installation

1. Download or clone this repository
2. Place the `RingMenuReborn` folder in your `Interface/AddOns` directory
3. Restart WoW or type `/reload`

## Usage

### Slash Commands
- `/rmr` or `/ringmenureborn` - Open the settings panel

### Configuration
1. Open **Game Menu** > **Options** > **AddOns** > **RingMenu Reborn**
2. Set a **Key Binding** to toggle the ring menu
3. Customize the ring settings:
   - **Name** - Optional name for the ring
   - **First Button Slot** - Starting action bar slot
   - **Number of Buttons** - How many buttons in the ring (1-24)
   - **Close on Click** - Auto-hide after clicking a button
   - **Backdrop Color** - Ring background color and opacity
   - **Radius** - Distance of buttons from center
   - **Angle** - Rotation of the ring

### Adding Actions
1. Press your keybind to show the ring at your cursor
2. Drag spells, items, or macros to the ring buttons like a regular action bar
3. Click any button to use it

### Multiple Rings
Use the **+** and **-** buttons in settings to create multiple rings with different keybinds and configurations.

## Action Bar Slots

The addon uses action bar slots for its buttons. Default is slots 13-24. If you have conflicts with shapeshifting or stance bars, refer to the [WoW Wiki ActionSlot](http://wowwiki.wikia.com/wiki/ActionSlot) page to find available ranges.

## Changes from Original

- Updated for WoW Classic Era 1.15.x API
- Replaced deprecated `OptionsCheckButtonTemplate` and `OptionsSliderTemplate`
- Replaced deprecated `CustomBindingHandler` with custom keybind capture
- Updated to new Settings API (`Settings.RegisterCanvasLayoutCategory`)
- Fixed XML backdrop handling for modern client
- Added `/rmr` as a shorter slash command

## Credits

- **Original Author**: jsb
- **Updated for 2025**: Community contribution

## License

This addon is provided as-is for the WoW community.
