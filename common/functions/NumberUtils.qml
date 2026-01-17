pragma Singleton
import Quickshell

Singleton {
    id: root
    
    function toRoman(num) {
        if (num <= 0) return num.toString();
        
        const romanNumerals = [
            [1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'],
            [100, 'C'], [90, 'XC'], [50, 'L'], [40, 'XL'],
            [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I']
        ];
        
        let result = '';
        for (let i = 0; i < romanNumerals.length; i++) {
            while (num >= romanNumerals[i][0]) {
                result += romanNumerals[i][1];
                num -= romanNumerals[i][0];
            }
        }
        return result;
    }
}
