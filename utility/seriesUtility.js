const numberSeries = [
    '',
    'কক', 'কখ', 'কগ', 'কঘ', 'কঙ', 
    'কচ', 'কছ', 'কজ', 'কঝ', 'কঞ',
    'কট', 'কঠ', 'কড', 'কঢ', 'কথ',
    'কদ', 'কন', 'কপ', 'কফ', 'কব',
    'কম', 'কল', 'কশ', 'কষ', 'কস', 'কহ', 
    'খক', 'খখ', 'খগ', 'খঘ', 'খঙ', 
    'খচ', 'খছ', 'খজ', 'খঝ', 'খঞ', 
    'খট', 'খঠ', 'খড', 'খঢ', 'খথ', 
    'খদ', 'খন', 'খপ', 'খফ', 'খব', 
    'খম', 'খল', 'খশ', 'খষ', 'খস', 'খহ', 
    'গক', 'গখ', 'গগ', 'গঘ', 'গঙ', 
    'গচ', 'গছ', 'গজ', 'গঝ', 'গঞ'
];

module.exports = {

    getSeries( series ) {
        
        series = parseInt(series);

        if ( series > 0 && series <= 62 ) {
            return numberSeries[series];
        } else {
            return '';
        }
    }

}
