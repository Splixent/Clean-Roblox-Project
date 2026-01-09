local SharedConstants = {

    potteryStationInfo = {
        ClayPatch = {
            levelStats = {
                ["0"] = {maxClay = 20, clayPerInterval = 1, harvestAmount = 1, harvestCooldown = 1, generateDelay = 3},
            }
        }
    }

}

table.freeze(SharedConstants)
return SharedConstants
