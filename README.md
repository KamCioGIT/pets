# rsg-pets by devchacha

A fully-featured pet companion system for RSG-Core with an immersive Wild West themed UI, health system, and persistent naming.

## Features

### 🎨 Wild West Themed UI
- Authentic 1899-style shop interface
- Custom "Wanted Poster" pet cards
- **NEW:** Interactive Pet Status Menu (Health, Hunger, Lifespan)
- **NEW:** Immersive Feeding Menu with custom progress bars

### 🐕 & 🐈 Companions
- 11 Dog Breeds (Shepherds, Huskies, Retrievers, etc.)
- Cats (Tabby)
- **Persistence:** Pet names are saved specifically to your pet item!
- **Lifespan:** Pets age and have a configured lifespan (default 60 days)

### 🏪 Interactive Shop
- Located at Valentine (customizable)
- Animated Shopkeeper NPC
- Use Third-Eye to interact

### 🎮 Advanced Behaviors
- **Needs System:** Hunger decays over time; affects health.
- **Commands:** Follow, Stay, Rest, Sleep.
- **Feeding:** Feed your pet various meats and breads to restore stats.
- **Animations:** Petting, eating, and sleeping animations.

## Dependencies
- [rsg-core]
- [rsg-inventory]
- [ox_lib]

## Installation

### 1. Add Resource
Copy the `rsg-pets` folder to your server's `resources` directory.

### 2. Add Items
Add pet items and food items to your `rsg-core/shared/items.lua`.
*See `installation/shared_items.lua` for the full list of pet items.*

**Required Food Items:**
- `bread`, `meat`, `venison`, `fish`, `pork`, `chicken`, `stew`

### 3. Start Resource
Add to your `server.cfg`:
```cfg
ensure rsg-pets
```

## Configuration
Edit `config.lua` to customize:
- **Pet Food:** Define which items can be fed and how much they restore.
- **Lifespan:** Set how long pets live (in real days).
- **Hunger Rate:** Adjust how fast hunger/health tick down.
- **Shop Location:** Move the generic store NPC anywhere.

## Usage

### 🛒 Buying a Pet
1. Go to the Pet Shop (Blip on map).
2. Use **Third-Eye (Alt)** on the Storekeeper.
3. Select "Open Pet Shop".
4. Purchase your companion.

### 🐕 Interacting with Pets
Use your pet item to spawn/dismiss.
**Third-Eye (Alt)** on your pet to access:
- **❤️ Pet:** Show affection.
- **🍖 Feed:** Open food menu.
- **📊 Check Status:** View health/hunger bars.
- **✏️ Rename:** Give your pet a unique name (Saved permanently!).
- **✋ Commands:** Stay, Follow, Rest.

## Commands
| Command | Description |
|---------|-------------|
| `/petwhistle` | Call your pet to you |
| `/petdismiss` | Send pet back to inventory |

## Credits
- Script created by **devchacha**
