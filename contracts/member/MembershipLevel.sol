pragma solidity ^0.4.25;

library MembershipLevel {
    struct Level {
        uint level; //member level
        address erc20; //fee contract
        uint256 amount; //fee amount
        uint extension; //seconds
    }
    
    struct Data {
        mapping(uint => Level) levels;
    }
    
    function addLevel(Data storage self, Level level) internal returns(bool) {
        require(level.level > 0 && level.extension > 0, "invalid membership fee parameters!");
        if(level.erc20 == address(0)){
            level.amount = 0;
        }
        self.levels[level.level] = level;
        return true;
    }
    
    function updateLevel(Data storage self, Level level) internal returns(bool) {
        require(self.levels[level.level].level == level.level, "membership level is not exist!");
        self.levels[level.level] = level;
    }
    
    function getLevel(Data storage self, uint level) internal view returns(Level) {
        require(self.levels[level].level == level, "invalid membership level!");
        return self.levels[level];
    }
    
    function isExist(Data storage self, uint level) internal view returns(bool) {
        return self.levels[level].level == level;
    }
    
}