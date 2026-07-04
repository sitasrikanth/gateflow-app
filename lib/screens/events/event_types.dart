import 'package:flutter/material.dart';

// ── Event Type Catalog ────────────────────────────────────────────────────────

enum EventCategory {
  festive,
  sports,
  entertainment,
  workshops,
  children,
  civic,
  market,
  other,
}

extension EventCategoryX on EventCategory {
  String get label {
    const m = {
      EventCategory.festive: 'Festive',
      EventCategory.sports: 'Sports',
      EventCategory.entertainment: 'Entertainment',
      EventCategory.workshops: 'Workshops',
      EventCategory.children: 'Children',
      EventCategory.civic: 'Civic',
      EventCategory.market: 'Market',
      EventCategory.other: 'Other',
    };
    return m[this]!;
  }

  String get emoji {
    const m = {
      EventCategory.festive: '🪔',
      EventCategory.sports: '🏅',
      EventCategory.entertainment: '🎬',
      EventCategory.workshops: '📚',
      EventCategory.children: '🧒',
      EventCategory.civic: '🌿',
      EventCategory.market: '🛍️',
      EventCategory.other: '📌',
    };
    return m[this]!;
  }
}

class EventTypeData {
  final String id;
  final String name;
  final String emoji;
  final String tagline;
  final EventCategory category;
  final List<Color> gradient;
  final String suggestedDescription;
  final List<Map<String, dynamic>> expenseCategories;
  final String imageUrl;

  const EventTypeData({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.category,
    required this.gradient,
    required this.suggestedDescription,
    required this.expenseCategories,
    required this.imageUrl,
  });
}

Map<String, dynamic> _c(String name, String icon, [List<String> subs = const []]) =>
    {'name': name, 'icon': icon, 'subCategories': List<String>.from(subs)};

// ── Full Catalog ──────────────────────────────────────────────────────────────

final List<EventTypeData> kAllEventTypes = [

  // ── FESTIVE ──────────────────────────────────────────────────────────────

  EventTypeData(
    id: 'ganesh_chaturthi',
    name: 'Ganesh Chaturthi',
    emoji: '🪔',
    tagline: 'Celebrate Bappa with the community',
    category: EventCategory.festive,
    gradient: const [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
    imageUrl: 'https://images.pexels.com/photos/29761491/pexels-photo-29761491.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community celebration of Ganesh Chaturthi with idol installation, daily poojas, cultural programs, and Visarjan procession.',
    expenseCategories: [
      _c('Ganesh Idol', '🪔', ['Idol Cost', 'Transportation', 'Visarjan Charges']),
      _c('Decoration', '🎨', ['Flowers', 'Thermocol Backdrop', 'Rangoli', 'LEDs']),
      _c('Prasad', '🍬', ['Modak', 'Laddu', 'Fruits', 'Peda', 'Dry Fruits']),
      _c('Priest / Pandit', '🙏', ['Dakshina', 'Pooja Items', 'Agarbatti & Camphor']),
      _c('Music & Sound', '🎵', ['Sound System', 'DJ / Band', 'Dhol Tasha']),
      _c('Annadam / Food', '🍚', ['Rice', 'Dal', 'Vegetables', 'Plates & Cups']),
      _c('Lighting', '💡', ['LED Strip Lights', 'Candles & Diyas', 'Generator']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'diwali',
    name: 'Diwali',
    emoji: '🎇',
    tagline: 'Festival of lights & joy',
    category: EventCategory.festive,
    gradient: const [Color(0xFFFFD700), Color(0xFFFF8C00)],
    imageUrl: 'https://images.pexels.com/photos/1898547/pexels-photo-1898547.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community Diwali celebration with rangoli competition, lamp-lighting ceremony, sweets distribution, and fireworks display.',
    expenseCategories: [
      _c('Decoration', '🎨', ['Diyas & Candles', 'Rangoli Colors', 'Flower Garlands', 'LED Lights']),
      _c('Sweets & Snacks', '🍬', ['Mithai Box', 'Dry Fruits', 'Namkeen', 'Chocolates']),
      _c('Fireworks', '🎆', ['Phuljhari', 'Chakri', 'Anar', 'Sky Shots']),
      _c('Pooja', '🙏', ['Lakshmi Idol', 'Pooja Thali', 'Agarbatti', 'Camphor']),
      _c('Music & Sound', '🎵', ['Speaker System', 'DJ']),
      _c('Food / Feast', '🍽️', ['Dinner Catering', 'Snacks', 'Beverages']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'holi',
    name: 'Holi',
    emoji: '🎨',
    tagline: 'Colors, music & togetherness',
    category: EventCategory.festive,
    gradient: const [Color(0xFFE91E63), Color(0xFF9C27B0)],
    imageUrl: 'https://images.pexels.com/photos/2693212/pexels-photo-2693212.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community Holi celebration with organic colors, water balloons, DJ music, thandai, and gujiya distribution.',
    expenseCategories: [
      _c('Colors & Equipment', '🎨', ['Organic Gulal', 'Water Balloons', 'Pichkari', 'Protective Sheets']),
      _c('Food & Drinks', '🥛', ['Thandai', 'Gujiya', 'Snacks', 'Beverages']),
      _c('Music & DJ', '🎵', ['DJ System', 'Sound Rental']),
      _c('Cleanup', '🧹', ['Cleaning Crew', 'Waste Bags', 'Water Tanker']),
      _c('Decoration', '🎊', ['Stage Setup', 'Banners']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'christmas',
    name: 'Christmas',
    emoji: '🎄',
    tagline: 'Joy, carols & community spirit',
    category: EventCategory.festive,
    gradient: const [Color(0xFF388E3C), Color(0xFFC62828)],
    imageUrl: 'https://images.pexels.com/photos/1303081/pexels-photo-1303081.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community Christmas celebration with tree decoration, carol singing, Secret Santa exchange, Christmas dinner, and cake cutting.',
    expenseCategories: [
      _c('Decoration', '🎄', ['Christmas Tree', 'Ornaments', 'Fairy Lights', 'Wreaths', 'Nativity Set']),
      _c('Food & Cake', '🎂', ['Christmas Cake', 'Plum Cake', 'Cookies', 'Dinner Catering', 'Beverages']),
      _c('Gifts & Santa', '🎁', ['Secret Santa Gifts', 'Gift Wrapping', 'Santa Costume']),
      _c('Entertainment', '🎤', ['Carol Singers', 'PA System', 'Band']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'eid',
    name: 'Eid / Ramzan',
    emoji: '🌙',
    tagline: 'Iftar, prayers & togetherness',
    category: EventCategory.festive,
    gradient: const [Color(0xFF00695C), Color(0xFF1565C0)],
    imageUrl: 'https://images.pexels.com/photos/3991843/pexels-photo-3991843.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community Iftar gathering, Eid prayers, biryani feast, and charitable activities for residents.',
    expenseCategories: [
      _c('Iftar / Feast', '🍖', ['Biryani', 'Kebabs', 'Haleem', 'Sweets', 'Beverages', 'Fruit Chaat']),
      _c('Decoration', '🌙', ['Moon & Star Lights', 'Lanterns', 'Banners']),
      _c('Prayer Setup', '🙏', ['Prayer Mats', 'PA System', 'Water Arrangement']),
      _c('Charity', '❤️', ['Zakat / Sadqa Collection', 'Food Packets for Needy']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'navratri',
    name: 'Navratri / Garba',
    emoji: '🕺',
    tagline: 'Nine nights of dance & devotion',
    category: EventCategory.festive,
    gradient: const [Color(0xFF6A1B9A), Color(0xFFE91E63)],
    imageUrl: 'https://images.pexels.com/photos/2187616/pexels-photo-2187616.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community Navratri celebration with Garba & Dandiya nights, Mata puja, fasting food, and costume competition.',
    expenseCategories: [
      _c('Music & DJ', '🎵', ['Live Garba Singer', 'DJ / Sound System', 'Microphone']),
      _c('Decoration', '🎨', ['Mata Idol', 'Flowers', 'Stage Decor', 'Lights']),
      _c('Prasad & Fasting Food', '🍽️', ['Sabudana Khichdi', 'Fruits', 'Kuttu Puris', 'Sweets']),
      _c('Costumes & Props', '👗', ['Dandiya Sticks', 'Costume Competition Prizes']),
      _c('Priest', '🙏', ['Aarti Expenses', 'Pooja Samagri']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'independence_day',
    name: 'Independence Day',
    emoji: '🇮🇳',
    tagline: 'Celebrate the spirit of the nation',
    category: EventCategory.festive,
    gradient: const [Color(0xFFFF9800), Color(0xFF4CAF50)],
    imageUrl: 'https://images.pexels.com/photos/1199516/pexels-photo-1199516.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Flag hoisting ceremony, patriotic songs, cultural performances, and sweet distribution.',
    expenseCategories: [
      _c('Flag & Ceremony', '🇮🇳', ['National Flag', 'Flag Pole', 'Garland']),
      _c('Sweets', '🍬', ['Laddus', 'Sweets Distribution']),
      _c('Cultural Program', '🎤', ['PA System', 'Costumes', 'Prizes']),
      _c('Decoration', '🎨', ['Banners', 'Tricolor Decoration', 'Flowers']),
      _c('Misc', '📦'),
    ],
  ),

  // ── SPORTS ───────────────────────────────────────────────────────────────

  EventTypeData(
    id: 'cricket',
    name: 'Cricket Tournament',
    emoji: '🏏',
    tagline: 'Boundary hits & community cheers',
    category: EventCategory.sports,
    gradient: const [Color(0xFF1565C0), Color(0xFF0288D1)],
    imageUrl: 'https://images.pexels.com/photos/3657154/pexels-photo-3657154.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Inter-block cricket tournament with league matches, knockout rounds, and a grand finals day with trophies.',
    expenseCategories: [
      _c('Equipment', '🏏', ['Cricket Ball', 'Bat & Stumps', 'Protective Gear', 'Nets']),
      _c('Prizes & Trophies', '🏆', ['Winner Trophy', 'Runner-up Trophy', 'Best Player Award', 'Medals']),
      _c('Refreshments', '🥤', ['Water / Drinks', 'Snacks', 'Energy Drinks']),
      _c('Ground Setup', '🌿', ['Ground Marking', 'Pitch Preparation', 'Seating']),
      _c('Umpire / Referee', '👨‍⚖️', ['Umpire Fee', 'Scorecard Materials']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'badminton',
    name: 'Badminton Tournament',
    emoji: '🏸',
    tagline: 'Smashes & rallies all day long',
    category: EventCategory.sports,
    gradient: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
    imageUrl: 'https://images.pexels.com/photos/8007218/pexels-photo-8007218.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Badminton singles & doubles tournament open to all age groups.',
    expenseCategories: [
      _c('Equipment', '🏸', ['Shuttlecocks', 'Badminton Net', 'Racket Strings']),
      _c('Prizes & Trophies', '🏆', ['Winner Trophy', 'Runner-up Trophy', 'Medals', 'Certificates']),
      _c('Court Setup', '🌿', ['Court Marking', 'Lighting Arrangement']),
      _c('Refreshments', '🥤', ['Water', 'Snacks', 'Sports Drinks']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'chess',
    name: 'Chess Tournament',
    emoji: '♟️',
    tagline: 'Battle of wits & strategy',
    category: EventCategory.sports,
    gradient: const [Color(0xFF37474F), Color(0xFF607D8B)],
    imageUrl: 'https://images.pexels.com/photos/260024/pexels-photo-260024.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community chess tournament with separate categories for juniors and adults, Swiss-system rounds, and prize distribution.',
    expenseCategories: [
      _c('Equipment', '♟️', ['Chess Boards', 'Chess Clocks', 'Score Sheets']),
      _c('Prizes', '🏆', ['Winner Trophy', 'Runner-up', 'Best Junior Award', 'Certificates']),
      _c('Refreshments', '🥤', ['Water', 'Snacks', 'Tea / Coffee']),
      _c('Venue Setup', '🪑', ['Tables & Chairs', 'Lighting']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'sports_day',
    name: 'Community Sports Day',
    emoji: '🏅',
    tagline: 'Multi-sport fun for all ages',
    category: EventCategory.sports,
    gradient: const [Color(0xFFE65100), Color(0xFFF57C00)],
    imageUrl: 'https://images.pexels.com/photos/3621104/pexels-photo-3621104.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Annual Sports Day with relay races, tug-of-war, sack race, carrom, table tennis, and prize distribution for all age groups.',
    expenseCategories: [
      _c('Equipment & Supplies', '🏅', ['Tug-of-War Rope', 'Sacks', 'Batons', 'Carrom Boards', 'Table Tennis']),
      _c('Prizes & Medals', '🏆', ['Gold/Silver/Bronze Medals', 'Trophies', 'Certificates', 'Gift Vouchers']),
      _c('Refreshments', '🥤', ['Water Stations', 'Snacks', 'Fruits', 'Sports Drinks']),
      _c('Ground Setup', '🌿', ['Track Marking', 'PA System', 'Seating']),
      _c('First Aid', '🩺', ['First Aid Kit', 'Medical Volunteer']),
      _c('Misc', '📦'),
    ],
  ),

  // ── ENTERTAINMENT ────────────────────────────────────────────────────────

  EventTypeData(
    id: 'movie_night',
    name: 'Movie Night',
    emoji: '🎬',
    tagline: 'Under the stars, big screen magic',
    category: EventCategory.entertainment,
    gradient: const [Color(0xFF1A237E), Color(0xFF311B92)],
    imageUrl: 'https://images.pexels.com/photos/7991579/pexels-photo-7991579.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Outdoor movie screening under the stars on the central lawn, with popcorn, snacks, and cozy seating for all residents.',
    expenseCategories: [
      _c('AV Equipment', '📽️', ['Projector', 'Inflatable Screen', 'Sound System', 'Generator']),
      _c('Food & Snacks', '🍿', ['Popcorn', 'Nachos', 'Cold Drinks', 'Snack Counter']),
      _c('Seating & Setup', '🪑', ['Chairs', 'Bean Bags', 'Carpets', 'Lighting']),
      _c('Decoration', '🎨', ['Banners', 'Fairy Lights', 'Themed Props']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'talent_show',
    name: 'Talent Show',
    emoji: '🎤',
    tagline: 'Discover hidden stars in your community',
    category: EventCategory.entertainment,
    gradient: const [Color(0xFFAD1457), Color(0xFFE91E63)],
    imageUrl: 'https://images.pexels.com/photos/1190297/pexels-photo-1190297.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community talent show with singing, dancing, comedy, and instrumental performances. Open to residents of all ages.',
    expenseCategories: [
      _c('Stage & Sound', '🎤', ['Stage Setup', 'Microphones', 'Sound System', 'Spotlights']),
      _c('Prizes', '🏆', ['Winner Trophy', 'Runner-up', 'Audience Choice Award', 'Certificates']),
      _c('Decoration', '🎊', ['Backdrop Banner', 'Flower Arrangements', 'Balloons']),
      _c('Refreshments', '🥤', ['Snacks', 'Beverages', 'Water']),
      _c('Emcee / Anchor', '🎙️', ['Emcee Fee', 'Judges Fee']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'potluck',
    name: 'Community Potluck',
    emoji: '🍲',
    tagline: 'Every home brings a dish, every heart shares',
    category: EventCategory.entertainment,
    gradient: const [Color(0xFF00695C), Color(0xFF00897B)],
    imageUrl: 'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community potluck dinner where every family brings a dish to share. Celebrate the diversity of cuisines.',
    expenseCategories: [
      _c('Venue Setup', '🪑', ['Tables', 'Chairs', 'Table Covers', 'Serving Dishes']),
      _c('Common Supplies', '🍽️', ['Plates & Cups', 'Napkins', 'Serving Spoons', 'Labels']),
      _c('Extras', '🥤', ['Cold Drinks', 'Water Station', 'Ice']),
      _c('Decoration', '🎊', ['Lights', 'Flowers', 'Banners']),
      _c('Music', '🎵', ['Speaker', 'Playlist Setup']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'dj_night',
    name: 'DJ Night / Party',
    emoji: '🎧',
    tagline: 'Let the music move the community',
    category: EventCategory.entertainment,
    gradient: const [Color(0xFF4A148C), Color(0xFF7B1FA2)],
    imageUrl: 'https://images.pexels.com/photos/1763075/pexels-photo-1763075.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community DJ night with professional sound system, dance floor, themed lighting, and mocktail counter.',
    expenseCategories: [
      _c('DJ & Sound', '🎧', ['DJ Fees', 'Sound System', 'Subwoofers', 'Lighting Rig']),
      _c('Decoration', '🎊', ['Dance Floor Setup', 'LED Lights', 'Fog Machine', 'Balloons']),
      _c('Food & Bar', '🥂', ['Mocktails', 'Snacks', 'Finger Food', 'Water']),
      _c('Venue', '🏛️', ['Party Hall Booking', 'Security', 'Cleanup']),
      _c('Misc', '📦'),
    ],
  ),

  // ── WORKSHOPS ────────────────────────────────────────────────────────────

  EventTypeData(
    id: 'health_wellness',
    name: 'Health & Wellness Camp',
    emoji: '🏥',
    tagline: 'Healthy residents, happy community',
    category: EventCategory.workshops,
    gradient: const [Color(0xFF00838F), Color(0xFF0097A7)],
    imageUrl: 'https://images.pexels.com/photos/3376790/pexels-photo-3376790.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Free health check-up camp with BP screening, sugar testing, eye check-up, and doctor consultations for all residents.',
    expenseCategories: [
      _c('Medical Supplies', '🩺', ['Test Kits', 'BP Monitors', 'Glucometers', 'Disposables']),
      _c('Doctor / Expert Fee', '👨‍⚕️', ['Doctor Consultation', 'Dietitian', 'Physiotherapist']),
      _c('Setup', '🏛️', ['Tables', 'Privacy Screens', 'Chairs', 'Signage']),
      _c('Refreshments', '🥤', ['Juices', 'Water', 'Healthy Snacks']),
      _c('Awareness Material', '📋', ['Pamphlets', 'Brochures', 'Medicine Kits']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'investment_talk',
    name: 'Investment / Finance Talk',
    emoji: '💰',
    tagline: 'Grow your wealth, grow your community',
    category: EventCategory.workshops,
    gradient: const [Color(0xFF1B5E20), Color(0xFF388E3C)],
    imageUrl: 'https://images.pexels.com/photos/6801642/pexels-photo-6801642.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Investment seminar covering mutual funds, SIPs, real estate, tax saving, and retirement planning for residents.',
    expenseCategories: [
      _c('Speaker / Expert Fee', '🎙️', ['Speaker Honorarium', 'Travel & Stay']),
      _c('AV & Setup', '📽️', ['Projector', 'Laptop', 'Sound', 'Screen']),
      _c('Materials', '📋', ['Booklets', 'Worksheets', 'Pen & Notepad']),
      _c('Refreshments', '☕', ['Tea / Coffee', 'Snacks', 'Water']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'cooking_class',
    name: 'Cooking Masterclass',
    emoji: '👨‍🍳',
    tagline: 'Recipes, techniques & flavors',
    category: EventCategory.workshops,
    gradient: const [Color(0xFFBF360C), Color(0xFFE64A19)],
    imageUrl: 'https://images.pexels.com/photos/3184183/pexels-photo-3184183.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community cooking masterclass featuring regional cuisines, baking, healthy cooking, and kids\' cooking sessions.',
    expenseCategories: [
      _c('Ingredients', '🥘', ['Raw Ingredients', 'Spices', 'Oils', 'Special Items']),
      _c('Chef / Instructor', '👨‍🍳', ['Chef Fee', 'Recipe Cards']),
      _c('Equipment', '🍳', ['Cookware Rental', 'Gas Burner', 'Utensils']),
      _c('Tasting', '🍽️', ['Serving Plates', 'Cutlery', 'Napkins']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'skill_workshop',
    name: 'Skill Workshop',
    emoji: '🛠️',
    tagline: 'Learn, share, grow together',
    category: EventCategory.workshops,
    gradient: const [Color(0xFF0D47A1), Color(0xFF1565C0)],
    imageUrl: 'https://images.pexels.com/photos/3184360/pexels-photo-3184360.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Skill-sharing workshop covering photography, coding, language learning, or creative arts for residents.',
    expenseCategories: [
      _c('Trainer Fee', '🎙️', ['Trainer / Facilitator Fee', 'Travel']),
      _c('Materials', '📋', ['Workbooks', 'Stationery', 'Props']),
      _c('AV Setup', '📽️', ['Projector', 'Laptop', 'Sound']),
      _c('Refreshments', '☕', ['Tea / Coffee', 'Snacks', 'Water']),
      _c('Venue', '🏛️', ['Room Setup', 'Chairs & Tables']),
      _c('Misc', '📦'),
    ],
  ),

  // ── CHILDREN ────────────────────────────────────────────────────────────

  EventTypeData(
    id: 'summer_camp',
    name: 'Summer Camp',
    emoji: '🌞',
    tagline: 'Fun, learning & friendship',
    category: EventCategory.children,
    gradient: const [Color(0xFFF57F17), Color(0xFFFBC02D)],
    imageUrl: 'https://images.pexels.com/photos/1620653/pexels-photo-1620653.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Summer camp for children featuring sports, arts & crafts, storytelling, yoga, and outdoor activities.',
    expenseCategories: [
      _c('Activities & Craft', '🎨', ['Art Supplies', 'Craft Materials', 'Sports Equipment']),
      _c('Instructor Fees', '👩‍🏫', ['Art Instructor', 'Sports Coach', 'Yoga Teacher']),
      _c('Snacks & Lunch', '🍱', ['Daily Snacks', 'Lunch', 'Water / Juices']),
      _c('Prizes & Certificates', '🏆', ['Participation Kits', 'Certificates', 'Medals']),
      _c('Safety', '🩺', ['First Aid Kit', 'Safety Gear']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'magic_show',
    name: 'Magic Show / Fun Event',
    emoji: '🎩',
    tagline: 'Wonder, laughter & excitement',
    category: EventCategory.children,
    gradient: const [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    imageUrl: 'https://images.pexels.com/photos/3905874/pexels-photo-3905874.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Professional magic show, puppet show, or clown performance for children with interactive segments and gift distribution.',
    expenseCategories: [
      _c('Performer Fee', '🎩', ['Magician / Performer Fee', 'Travel']),
      _c('Snacks & Treats', '🍭', ['Candies', 'Balloons', 'Juice Boxes', 'Cake']),
      _c('Decoration', '🎊', ['Balloons', 'Streamers', 'Photo Booth Props']),
      _c('Gifts', '🎁', ['Return Gifts', 'Gift Bags']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'art_competition',
    name: 'Art & Painting Competition',
    emoji: '🖌️',
    tagline: 'Every child is an artist',
    category: EventCategory.children,
    gradient: const [Color(0xFFE91E63), Color(0xFFF06292)],
    imageUrl: 'https://images.pexels.com/photos/1183992/pexels-photo-1183992.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Painting and art competition for children across age categories with themes, prizes, and an exhibition of entries.',
    expenseCategories: [
      _c('Art Supplies', '🖌️', ['Drawing Sheets', 'Colour Boxes', 'Brushes', 'Crayons']),
      _c('Prizes & Certificates', '🏆', ['Trophies', 'Medals', 'Gift Vouchers', 'Certificates']),
      _c('Setup', '🪑', ['Tables', 'Easels', 'Sheets & Covers']),
      _c('Refreshments', '🥤', ['Juice Boxes', 'Biscuits']),
      _c('Misc', '📦'),
    ],
  ),

  // ── CIVIC ────────────────────────────────────────────────────────────────

  EventTypeData(
    id: 'cleanup_drive',
    name: 'Clean-up Drive',
    emoji: '🧹',
    tagline: 'Clean society, proud residents',
    category: EventCategory.civic,
    gradient: const [Color(0xFF33691E), Color(0xFF558B2F)],
    imageUrl: 'https://images.pexels.com/photos/6591154/pexels-photo-6591154.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community-wide cleanliness drive covering common areas, gardens, parking, and stairwells with resident volunteers.',
    expenseCategories: [
      _c('Cleaning Supplies', '🧹', ['Brooms', 'Mops', 'Dustbins', 'Garbage Bags', 'Cleaning Chemicals']),
      _c('PPE & Safety', '🧤', ['Gloves', 'Masks', 'Safety Vests']),
      _c('Refreshments', '🥤', ['Water', 'Energy Drinks', 'Snacks for Volunteers']),
      _c('Awareness', '📢', ['Banners', 'Pamphlets', 'PA Announcement']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'charity_drive',
    name: 'Charity / Donation Drive',
    emoji: '❤️',
    tagline: 'Give back, uplift together',
    category: EventCategory.civic,
    gradient: const [Color(0xFFC62828), Color(0xFFE53935)],
    imageUrl: 'https://images.pexels.com/photos/6994982/pexels-photo-6994982.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Collection drive for clothes, books, food, or funds for underprivileged communities, old age homes, or schools.',
    expenseCategories: [
      _c('Collection Setup', '📦', ['Collection Bins', 'Sorting Tables', 'Packaging']),
      _c('Transport', '🚗', ['Vehicle for Delivery', 'Fuel']),
      _c('Awareness', '📢', ['Banners', 'Pamphlets']),
      _c('Refreshments', '🥤', ['Water', 'Snacks for Volunteers']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'tree_plantation',
    name: 'Tree Plantation Drive',
    emoji: '🌱',
    tagline: 'Plant a tree, grow a future',
    category: EventCategory.civic,
    gradient: const [Color(0xFF1B5E20), Color(0xFF43A047)],
    imageUrl: 'https://images.pexels.com/photos/1072824/pexels-photo-1072824.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community tree plantation drive in common areas with native saplings and eco-awareness activities.',
    expenseCategories: [
      _c('Saplings & Plants', '🌱', ['Native Saplings', 'Flowering Plants', 'Pots & Soil']),
      _c('Tools', '🪣', ['Spades', 'Watering Cans', 'Gloves', 'Fertilizer']),
      _c('Refreshments', '🥤', ['Water', 'Snacks', 'Juice']),
      _c('Awareness', '📢', ['Banners', 'Certificates for Planters']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'pet_adoption',
    name: 'Pet Adoption Drive',
    emoji: '🐾',
    tagline: 'Find them a forever home',
    category: EventCategory.civic,
    gradient: const [Color(0xFF4E342E), Color(0xFF6D4C41)],
    imageUrl: 'https://images.pexels.com/photos/1108099/pexels-photo-1108099.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community pet adoption and awareness event in collaboration with local shelters — responsible ownership, adoption, and neutering drives.',
    expenseCategories: [
      _c('Venue Setup', '🪑', ['Enclosures', 'Tables', 'Signage']),
      _c('Pet Supplies', '🐾', ['Pet Food', 'Water Bowls', 'First Aid for Pets']),
      _c('Awareness', '📢', ['Banners', 'Brochures', 'Social Media Prints']),
      _c('Refreshments', '🥤', ['Water', 'Snacks for Volunteers']),
      _c('Misc', '📦'),
    ],
  ),

  // ── MARKET ───────────────────────────────────────────────────────────────

  EventTypeData(
    id: 'flea_market',
    name: 'Flea Market / Exhibition',
    emoji: '🛍️',
    tagline: 'Discover, shop & connect',
    category: EventCategory.market,
    gradient: const [Color(0xFF880E4F), Color(0xFFAD1457)],
    imageUrl: 'https://images.pexels.com/photos/5632397/pexels-photo-5632397.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community flea market where residents and local vendors set up stalls for clothes, crafts, food, plants, and pre-loved items.',
    expenseCategories: [
      _c('Stall Setup', '🛍️', ['Tables', 'Canopies / Tents', 'Signage', 'Extension Cords']),
      _c('Publicity', '📢', ['Banners', 'Social Media Flyers', 'PA Announcement']),
      _c('Food Court', '🍜', ['Food Stall Setup', 'Seating Area']),
      _c('Security & Ops', '🔒', ['Security Staff', 'Cleaning Crew', 'Waste Management']),
      _c('Entertainment', '🎵', ['Background Music', 'Kids Corner Setup']),
      _c('Misc', '📦'),
    ],
  ),

  EventTypeData(
    id: 'food_festival',
    name: 'Food Festival',
    emoji: '🍜',
    tagline: 'A world of flavors in one place',
    category: EventCategory.market,
    gradient: const [Color(0xFFE65100), Color(0xFFFF6F00)],
    imageUrl: 'https://images.pexels.com/photos/1640772/pexels-photo-1640772.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: 'Community food festival showcasing regional cuisines, home-made specialties, baking, and street food from resident families.',
    expenseCategories: [
      _c('Stall Setup', '🏮', ['Stall Tables', 'Canopies', 'Serving Counters']),
      _c('Common Kitchen', '🍳', ['Gas Cylinders', 'Utensils', 'Ingredients']),
      _c('Decoration', '🎨', ['Themed Decor', 'Lights', 'Banners']),
      _c('PA System', '🎵', ['Speaker', 'Microphone']),
      _c('Hygiene', '🧹', ['Disposable Plates', 'Napkins', 'Handwash Stations']),
      _c('Prizes', '🏆', ['Best Dish Award', 'Certificates']),
      _c('Misc', '📦'),
    ],
  ),

  // ── OTHER ─────────────────────────────────────────────────────────────────

  EventTypeData(
    id: 'other',
    name: 'Other / Custom',
    emoji: '📌',
    tagline: 'Something unique for your community',
    category: EventCategory.other,
    gradient: const [Color(0xFF455A64), Color(0xFF607D8B)],
    imageUrl: 'https://images.pexels.com/photos/2747449/pexels-photo-2747449.jpeg?auto=compress&cs=tinysrgb&w=800',
    suggestedDescription: '',
    expenseCategories: [
      _c('Venue & Setup', '🏛️'),
      _c('Food & Beverages', '🍽️'),
      _c('Equipment', '🔧'),
      _c('Decoration', '🎨'),
      _c('Prizes & Gifts', '🎁'),
      _c('Misc', '📦'),
    ],
  ),
];

// ── Lookup helpers ────────────────────────────────────────────────────────────

EventTypeData? eventTypeById(String? id) {
  if (id == null || id.isEmpty) return null;
  try {
    return kAllEventTypes.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}

List<EventTypeData> eventTypesByCategory(EventCategory cat) =>
    kAllEventTypes.where((t) => t.category == cat).toList();

// Fuzzy match by name — used for migrating old events that have no eventTypeId
EventTypeData? eventTypeByName(String? name) {
  if (name == null || name.isEmpty) return null;
  final lower = name.toLowerCase();
  // Exact name match first
  try {
    return kAllEventTypes.firstWhere(
        (t) => t.name.toLowerCase() == lower);
  } catch (_) {}
  // Partial match — event name contains type name or vice versa
  try {
    return kAllEventTypes.firstWhere(
        (t) => lower.contains(t.name.toLowerCase()) ||
               t.name.toLowerCase().contains(lower));
  } catch (_) {}
  // Word-overlap match — handles extra words (year, prefix) or a typo in one
  // word of the event name, e.g. "MPR Badminton" ~ "Badminton Tournament" or
  // "Ganesh Chathurthi 2026" ~ "Ganesh Chaturthi". Only matches on a word
  // that is unique to a single event type, to avoid ambiguous words like
  // "Tournament" (shared by Cricket/Badminton/Chess) picking the wrong one.
  final nameWords = lower.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 4).toSet();
  if (nameWords.isEmpty) return null;
  final wordToTypes = <String, List<EventTypeData>>{};
  for (final t in kAllEventTypes) {
    for (final w in t.name.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 4)) {
      wordToTypes.putIfAbsent(w, () => []).add(t);
    }
  }
  for (final w in nameWords) {
    final matches = wordToTypes[w];
    if (matches != null && matches.length == 1) return matches.first;
  }
  return null;
}

LinearGradient gradientFor(EventTypeData type,
        {AlignmentGeometry begin = Alignment.topLeft,
        AlignmentGeometry end = Alignment.bottomRight}) =>
    LinearGradient(colors: type.gradient, begin: begin, end: end);

Color primaryColorFor(EventTypeData type) => type.gradient.first;
