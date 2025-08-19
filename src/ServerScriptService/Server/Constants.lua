local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local SharedConstants = require(Shared.Constants)
local ScriptUtils = require(Shared.ScriptUtils)

local Constants = {

	profileSettings = {
		profileTemplate = {
            loginInfo = {
                totalLogins = 0,
                lastLogin = 0,
                loginTime = 0,
                totalPlaytime = 0
            },

            keybinds = {
                sprint = {
                    moduleName = "MovementHandler",
                    keyCode = "LeftShift",
                },
                dash = {
                    moduleName = "MovementHandler",
                    keyCode = "Q",
                },
                shiftLock = {
                    moduleName = "CameraHandler",
                    keyCode = "LeftAlt",
                },
                equipWeapon = {
                    moduleName = "EquipmentHandler",
                    keyCode = "E",
                },
                m1 = {
                    moduleName = "CombatHandler",
                    mouse = true,
                    keyCode = "MouseButton1",
                },
                block = {
                    moduleName = "CombatHandler",
                    keyCode = "F",
                }
            },
            mobileKeybindInfos = {
                shiftLock = {
                    location = {0.923928, 0.112299},
                    size = {0.0484094, 0.0935829},
                },
                sprint = {
                    location = {0.031812, 0.871658},
                    size = {0.0484094, 0.0935829},
                },
                dash = {
                    location = {0.748, 0.389},
                    size = {0.0484094, 0.0935829},
                },
                equipWeapon = {
                    location = {0.695712, 0.5},
                    size = {0.0484094, 0.0935829},
                },
                m1 = {
                    location = {0.758212, 0.486098},
                    size = {0.128017, 0.227797},
                },
                block = {
                    location = {0.98212, 0.486098},
                    size = {0.128017, 0.227797},
                }
            },

            settings = {
                toggleSprint = {
                    settingType = "boolean",
                    value = false
                }
            },

            equipment = {
                weapon = "StarterKatana"
            }
		},
	},

    
    
    states = {
        loaded = false,
        inGame = false,

        weapon = {
            isEquipped = false,
            lastEquip = 0,
            
            attackNumber = 1,
            lastAttack = 0,
            weaponCooldown = 0,
            hitWindowOpen = false,

            blocking = false,
            blockStatTime = 0,
        },

        effectCooldowns = {
            flashstep = {
                cooldownTime = 2,
                lastUsed = 0,
                enabled = true,
            }
        },
    },
    codes = {
        "TestCode123"
    },
    oldCodes = {
        
    },

    serverNames = {
        first = {
           {weight = 1, object = "Acidic"},
           {weight = 1, object = "Ashy"},
           {weight = 1, object = "Barnyard"},
           {weight = 1, object = "Burnt"},
           {weight = 1, object = "Buttery"},
           {weight = 1, object = "Cardboard"},
           {weight = 1, object = "Caustic"},
           {weight = 1, object = "Citrus"},
           {weight = 1, object = "Chalky"},
           {weight = 1, object = "Clean"},
           {weight = 1, object = "Cooked"},
           {weight = 1, object = "Delicate"},
           {weight = 1, object = "Earthy"},
           {weight = 1, object = "Green"},
           {weight = 1, object = "Medicinal"},
           {weight = 1, object = "Musty"},
           {weight = 1, object = "Pungent"},
           {weight = 1, object = "Rancid"},
           {weight = 1, object = "Smoky"},
           {weight = 1, object = "Tangy"},
           {weight = 1, object = "Tart"},
           {weight = 1, object = "Vegetal"},
           {weight = 1, object = "Bitter"},
           {weight = 1, object = "Balsamic"},
           {weight = 1, object = "Divine"},
           {weight = 1, object = "Dry"},
           {weight = 1, object = "Flavored"},
           {weight = 1, object = "Flavorful"},
           {weight = 1, object = "Fruity"},
           {weight = 1, object = "Heavenly"},
           {weight = 1, object = "Hot"},
           {weight = 1, object = "Juicy"},
           {weight = 1, object = "Luscious"},
           {weight = 1, object = "Mouthwatering"},
           {weight = 1, object = "Pickled"},
           {weight = 1, object = "Rich"},
           {weight = 1, object = "Savory"},
           {weight = 1, object = "Sour"},
           {weight = 1, object = "Spicy"},
           {weight = 1, object = "Sugary"},
           {weight = 1, object = "Sweetened"},
           {weight = 1, object = "Tasteless"},
           {weight = 1, object = "Yummy"},
           {weight = 1, object = "Zesty"},
        },
        last = {
           {weight = 1, object = "Salad"},
           {weight = 1, object = "Chicken"},
           {weight = 1, object = "Cheese"},
           {weight = 1, object = "Rice"},
           {weight = 1, object = "Tea"},
           {weight = 1, object = "Coffee"},
           {weight = 1, object = "Milk"},
           {weight = 1, object = "Eggs"},
           {weight = 1, object = "Apple"},
           {weight = 1, object = "Soup"},
           {weight = 1, object = "Yogurt"},
           {weight = 1, object = "Bread"},
           {weight = 1, object = "Pasta"},
           {weight = 1, object = "Fries"},
           {weight = 1, object = "Pancakes"},
           {weight = 1, object = "Burger"},
           {weight = 1, object = "Pizza"},
           {weight = 1, object = "Pie"},
           {weight = 1, object = "Banana"},
           {weight = 1, object = "Bagel"},
           {weight = 1, object = "Muffin"},
           {weight = 1, object = "Alfredo"},
           {weight = 1, object = "Cheesecake"},
           {weight = 1, object = "Chips"},
           {weight = 1, object = "Tacos"},
           {weight = 1, object = "Burrito"},
           {weight = 1, object = "Chimichanga"},
           {weight = 1, object = "Enchilada"},
           {weight = 1, object = "Salsa"},
           {weight = 1, object = "Broccoli"},
           {weight = 1, object = "Kiwi"},
           {weight = 1, object = "Tomato"},
           {weight = 1, object = "Steak"},
           {weight = 1, object = "Ribs"},
           {weight = 1, object = "Biscuit"},
           {weight = 1, object = "Fried-Chicken"},
           {weight = 1, object = "Bacon"},
           {weight = 1, object = "Hot-Dog"},
           {weight = 1, object = "Sausage"},
           {weight = 1, object = "Brownie"},
           {weight = 1, object = "Cookie"},
           {weight = 1, object = "Donut"},
           {weight = 1, object = "Turkey"},
           {weight = 1, object = "Cranberry"},
           {weight = 1, object = "Gravy"},
           {weight = 1, object = "Lamb-Chops"},
           {weight = 1, object = "Ham"},
           {weight = 1, object = "Sushi"},
           {weight = 1, object = "Teriyaki"},
           {weight = 1, object = "Popcorn"},
           {weight = 1, object = "Shrimp"},
           {weight = 1, object = "Lasagna"},
           {weight = 1, object = "Ravioli"},
           {weight = 1, object = "Meatballs"},
           {weight = 1, object = "Nachos"},
           {weight = 1, object = "Crepes"},
           {weight = 1, object = "Chicken-Nuggets"},
           {weight = 1, object = "Potato"},
           {weight = 1, object = "Cantalope"},
           {weight = 1, object = "Orange"},
           {weight = 1, object = "Strawberries"},
           {weight = 1, object = "Peaches"},
           {weight = 1, object = "Mango"},
           {weight = 1, object = "Raspberries"},
           {weight = 1, object = "Blueberries"},
        }
    }
}

table.freeze(Constants)



return Constants