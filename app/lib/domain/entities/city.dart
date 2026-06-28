import 'enums.dart';

/// A selectable city within a [Region] (state). Region matching is done on the
/// **city** `wireValue` (a User is matched only with TravAcsers in the same
/// city). Delhi NCR is modelled as a single city covering the whole NCR, so
/// everyone there matches as one unit; larger states expose distinct cities
/// (e.g. Mumbai ≠ Pune).
///
/// This is a curated list of major cities — expand as coverage grows. Each
/// state has at least one city so the cascading dropdown is always usable.
class City {
  const City(this.wireValue, this.label, this.state);

  final String wireValue;
  final String label;
  final Region state;

  /// Cities belonging to [state], in declaration order.
  static List<City> forState(Region state) =>
      all.where((c) => c.state == state).toList(growable: false);

  static City? fromWire(String? value) {
    if (value == null) return null;
    for (final c in all) {
      if (c.wireValue == value) return c;
    }
    return null;
  }

  static const List<City> all = [
    // Delhi NCR — single combined city (whole NCR matches together).
    City('delhi_ncr', 'Delhi NCR', Region.delhiNcr),

    // Andhra Pradesh
    City('visakhapatnam', 'Visakhapatnam', Region.andhraPradesh),
    City('vijayawada', 'Vijayawada', Region.andhraPradesh),
    City('guntur', 'Guntur', Region.andhraPradesh),
    City('tirupati', 'Tirupati', Region.andhraPradesh),
    // Arunachal Pradesh
    City('itanagar', 'Itanagar', Region.arunachalPradesh),
    // Assam
    City('guwahati', 'Guwahati', Region.assam),
    City('dibrugarh', 'Dibrugarh', Region.assam),
    City('silchar', 'Silchar', Region.assam),
    // Bihar
    City('patna', 'Patna', Region.bihar),
    City('gaya', 'Gaya', Region.bihar),
    City('bhagalpur', 'Bhagalpur', Region.bihar),
    City('muzaffarpur', 'Muzaffarpur', Region.bihar),
    // Chhattisgarh
    City('raipur', 'Raipur', Region.chhattisgarh),
    City('bhilai', 'Bhilai', Region.chhattisgarh),
    City('bilaspur_cg', 'Bilaspur', Region.chhattisgarh),
    // Goa
    City('panaji', 'Panaji', Region.goa),
    City('margao', 'Margao', Region.goa),
    // Gujarat
    City('ahmedabad', 'Ahmedabad', Region.gujarat),
    City('surat', 'Surat', Region.gujarat),
    City('vadodara', 'Vadodara', Region.gujarat),
    City('rajkot', 'Rajkot', Region.gujarat),
    // Haryana (non-NCR)
    City('chandigarh_hr', 'Chandigarh (HR)', Region.haryana),
    City('panipat', 'Panipat', Region.haryana),
    City('ambala', 'Ambala', Region.haryana),
    City('karnal', 'Karnal', Region.haryana),
    // Himachal Pradesh
    City('shimla', 'Shimla', Region.himachalPradesh),
    City('dharamshala', 'Dharamshala', Region.himachalPradesh),
    // Jharkhand
    City('ranchi', 'Ranchi', Region.jharkhand),
    City('jamshedpur', 'Jamshedpur', Region.jharkhand),
    City('dhanbad', 'Dhanbad', Region.jharkhand),
    // Karnataka
    City('bengaluru', 'Bengaluru', Region.karnataka),
    City('mysuru', 'Mysuru', Region.karnataka),
    City('mangaluru', 'Mangaluru', Region.karnataka),
    City('hubballi', 'Hubballi-Dharwad', Region.karnataka),
    // Kerala
    City('thiruvananthapuram', 'Thiruvananthapuram', Region.kerala),
    City('kochi', 'Kochi', Region.kerala),
    City('kozhikode', 'Kozhikode', Region.kerala),
    City('thrissur', 'Thrissur', Region.kerala),
    // Madhya Pradesh
    City('indore', 'Indore', Region.madhyaPradesh),
    City('bhopal', 'Bhopal', Region.madhyaPradesh),
    City('jabalpur', 'Jabalpur', Region.madhyaPradesh),
    City('gwalior', 'Gwalior', Region.madhyaPradesh),
    // Maharashtra
    City('mumbai', 'Mumbai', Region.maharashtra),
    City('pune', 'Pune', Region.maharashtra),
    City('nagpur', 'Nagpur', Region.maharashtra),
    City('nashik', 'Nashik', Region.maharashtra),
    City('thane', 'Thane', Region.maharashtra),
    City('aurangabad_mh', 'Chhatrapati Sambhajinagar', Region.maharashtra),
    // Manipur
    City('imphal', 'Imphal', Region.manipur),
    // Meghalaya
    City('shillong', 'Shillong', Region.meghalaya),
    // Mizoram
    City('aizawl', 'Aizawl', Region.mizoram),
    // Nagaland
    City('kohima', 'Kohima', Region.nagaland),
    City('dimapur', 'Dimapur', Region.nagaland),
    // Odisha
    City('bhubaneswar', 'Bhubaneswar', Region.odisha),
    City('cuttack', 'Cuttack', Region.odisha),
    City('rourkela', 'Rourkela', Region.odisha),
    // Punjab
    City('ludhiana', 'Ludhiana', Region.punjab),
    City('amritsar', 'Amritsar', Region.punjab),
    City('jalandhar', 'Jalandhar', Region.punjab),
    City('patiala', 'Patiala', Region.punjab),
    // Rajasthan
    City('jaipur', 'Jaipur', Region.rajasthan),
    City('jodhpur', 'Jodhpur', Region.rajasthan),
    City('udaipur', 'Udaipur', Region.rajasthan),
    City('kota', 'Kota', Region.rajasthan),
    // Sikkim
    City('gangtok', 'Gangtok', Region.sikkim),
    // Tamil Nadu
    City('chennai', 'Chennai', Region.tamilNadu),
    City('coimbatore', 'Coimbatore', Region.tamilNadu),
    City('madurai', 'Madurai', Region.tamilNadu),
    City('tiruchirappalli', 'Tiruchirappalli', Region.tamilNadu),
    // Telangana
    City('hyderabad', 'Hyderabad', Region.telangana),
    City('warangal', 'Warangal', Region.telangana),
    // Tripura
    City('agartala', 'Agartala', Region.tripura),
    // Uttar Pradesh (non-NCR)
    City('lucknow', 'Lucknow', Region.uttarPradesh),
    City('kanpur', 'Kanpur', Region.uttarPradesh),
    City('varanasi', 'Varanasi', Region.uttarPradesh),
    City('agra', 'Agra', Region.uttarPradesh),
    City('prayagraj', 'Prayagraj', Region.uttarPradesh),
    // Uttarakhand
    City('dehradun', 'Dehradun', Region.uttarakhand),
    City('haridwar', 'Haridwar', Region.uttarakhand),
    // West Bengal
    City('kolkata', 'Kolkata', Region.westBengal),
    City('howrah', 'Howrah', Region.westBengal),
    City('siliguri', 'Siliguri', Region.westBengal),
    City('durgapur', 'Durgapur', Region.westBengal),
    // Union Territories
    City('port_blair', 'Port Blair', Region.andamanNicobar),
    City('chandigarh_city', 'Chandigarh', Region.chandigarh),
    City('daman', 'Daman', Region.dnhDd),
    City('silvassa', 'Silvassa', Region.dnhDd),
    City('srinagar', 'Srinagar', Region.jammuKashmir),
    City('jammu', 'Jammu', Region.jammuKashmir),
    City('leh', 'Leh', Region.ladakh),
    City('kavaratti', 'Kavaratti', Region.lakshadweep),
    City('puducherry_city', 'Puducherry', Region.puducherry),
  ];
}
