// Explore seed itineraries: 5 Thailand, 5 Japan, 20 elsewhere.
//
// Each stop is a search query, resolved at seed time to a real Google place, so
// names, coordinates, photos and ratings come from the provider rather than from
// this file. Keep queries specific ("<landmark>, <city>") so the first result is
// the intended place; seed.mjs also rejects results farther than radiusKm from
// the destination. `chargerNear` adds the fastest real EV charger within 20 km of
// that place. Notes are published (includeNotes), so keep them factual and
// evergreen: no prices or opening hours that go stale.

const s = (q, time, timeEnd, note) => ({ q, time, timeEnd, note });
const charge = (chargerNear, time, timeEnd, note) => ({ chargerNear, time, timeEnd, note });

export const plans = [
  // ---------------------------------------------------------------- Thailand
  {
    slug: "th-chiang-mai",
    title: "Chiang Mai Old City and Doi Suthep",
    destination: "Chiang Mai, Thailand",
    days: [
      [
        s("Wat Chedi Luang, Chiang Mai", "09:00", "10:30", "Go early, before the tour groups. Shoulders and knees covered."),
        s("Wat Phra Singh, Chiang Mai", "10:45", "11:45", "Walkable from Wat Chedi Luang through the old city lanes."),
        s("Khao Soi Mae Sai, Chiang Mai", "12:00", "13:00", "Northern-style khao soi. Expect a short queue at lunch."),
        s("Tha Phae Gate, Chiang Mai", "17:00", "18:00", "Golden-hour photos, then walk into the evening market streets."),
      ],
      [
        s("Wat Phra That Doi Suthep, Chiang Mai", "08:00", "10:00", "Take the 300-step Naga staircase or the funicular. Cooler up top, so bring a layer."),
        s("Bhubing Palace, Chiang Mai", "10:15", "11:30", "Royal winter palace gardens a few minutes above Doi Suthep."),
        s("Nimmanhaemin Road, Chiang Mai", "15:00", "18:00", "Cafe and design-shop district. Good for an afternoon slow-down."),
      ],
      [
        s("Wat Umong, Chiang Mai", "08:30", "10:00", "Forest temple with meditation tunnels. Quiet in the morning."),
        s("Chiang Mai Night Bazaar", "18:00", "21:00", "Handicrafts and street food. Bargain politely."),
      ],
    ],
  },
  {
    slug: "th-khao-yai-ev",
    title: "Bangkok to Khao Yai EV Weekend",
    destination: "Khao Yai National Park, Thailand",
    radiusKm: 200,
    days: [
      [
        charge("Pak Chong, Nakhon Ratchasima", "10:00", "10:45", "Top up before heading up to the park. Chargers along Mittraphap Road fill up on holiday weekends."),
        s("PB Valley Khao Yai Winery", "11:30", "13:00", "Vineyard tour and lunch with a view of the hills."),
        s("Primo Piazza Khao Yai", "14:00", "16:00", "Italian-themed hillside village. Popular with families."),
        s("Palio Khao Yai", "16:30", "18:30", "Shopping street with cafes. Good sunset stop."),
      ],
      [
        s("Haew Suwat Waterfall, Khao Yai", "08:00", "10:00", "Enter the national park early for the best chance of seeing wildlife on the road."),
        s("Khao Yai National Park Visitor Center", "10:30", "11:30", "Ask rangers about trail conditions and guided walks."),
        s("Pha Diao Dai Viewpoint, Khao Yai", "12:00", "13:00", "One of the highest viewpoints in the park. Short boardwalk."),
        charge("Pak Chong, Nakhon Ratchasima", "15:00", "15:45", "Charge before the drive back to Bangkok."),
      ],
    ],
  },
  {
    slug: "th-krabi",
    title: "Krabi: Ao Nang, Railay and the Islands",
    destination: "Ao Nang, Krabi, Thailand",
    days: [
      [
        s("Ao Nang Beach, Krabi", "15:00", "18:30", "Settle in and catch sunset from the beachfront promenade."),
        s("Ao Nang Landmark Night Market", "19:00", "21:00", "Seafood and Thai street food close to the beach."),
      ],
      [
        s("Railay Beach, Krabi", "09:00", "12:00", "Reached only by longtail boat from Ao Nang. Check the last boat back."),
        s("Phra Nang Cave Beach, Krabi", "12:30", "15:00", "Limestone cliffs and a small shrine cave. Great for swimming."),
        s("Railay Viewpoint, Krabi", "15:30", "16:30", "Steep, muddy scramble. Wear proper shoes, not flip-flops."),
      ],
      [
        s("Hong Island, Krabi", "08:30", "12:00", "Book an island-hopping boat. The lagoon is best at high tide."),
        s("Tiger Cave Temple, Krabi", "15:00", "17:30", "1,260 steps to the summit shrine. Bring water."),
      ],
    ],
  },
  {
    slug: "th-hua-hin-ev",
    title: "Hua Hin and Pranburi Coast Drive",
    destination: "Hua Hin, Thailand",
    radiusKm: 120,
    days: [
      [
        s("Phra Nakhon Khiri Historical Park, Phetchaburi", "09:00", "11:00", "Hilltop palace on the way down from Bangkok. Watch your bags around the monkeys."),
        charge("Cha-am, Phetchaburi", "11:30", "12:15", "Top up in Cha-am before Hua Hin."),
        s("Maruekhathaiyawan Palace, Cha-am", "12:30", "13:30", "Teak seaside palace on stilts. Modest dress required."),
        s("Hua Hin Railway Station", "16:00", "16:45", "Historic royal pavilion station, a classic photo stop."),
        s("Cicada Market, Hua Hin", "18:00", "21:00", "Weekend art and food market."),
      ],
      [
        s("Sam Roi Yot National Park", "08:00", "12:00", "Phraya Nakhon Cave is a steep hike plus a beach walk. Start early for the light beam."),
        s("Khao Kalok, Pranburi", "13:00", "15:00", "Quiet beach south of Hua Hin."),
        charge("Hua Hin, Prachuap Khiri Khan", "16:00", "16:45", "Charge before the return drive north."),
      ],
    ],
  },
  {
    slug: "th-chiang-rai",
    title: "Chiang Rai Temples and the Golden Triangle",
    destination: "Chiang Rai, Thailand",
    radiusKm: 100,
    days: [
      [
        s("Wat Rong Khun White Temple, Chiang Rai", "08:00", "09:30", "Arrive at opening. It gets crowded by mid-morning."),
        s("Baan Dam Museum, Chiang Rai", "10:00", "11:30", "The Black House. A striking contrast to the White Temple."),
        s("Wat Rong Suea Ten Blue Temple, Chiang Rai", "13:00", "14:00", "Vivid blue interior. Photos are allowed inside."),
        s("Chiang Rai Clock Tower", "19:00", "19:30", "The evening light show runs a few times each night."),
      ],
      [
        s("Singha Park, Chiang Rai", "08:30", "10:30", "Tea fields and lakes. Rent a bike or ride the tram."),
        s("Golden Triangle Viewpoint, Chiang Saen", "12:30", "13:30", "Where Thailand, Laos and Myanmar meet on the Mekong."),
        s("Hall of Opium, Chiang Saen", "13:45", "15:30", "Well-made museum on the region's history."),
      ],
    ],
  },

  // ------------------------------------------------------------------- Japan
  {
    slug: "jp-kyoto",
    title: "Kyoto Temples, Gion and Arashiyama",
    destination: "Kyoto, Japan",
    days: [
      [
        s("Fushimi Inari Taisha, Kyoto", "07:30", "10:00", "Go at dawn for empty torii gates. The full loop takes 2 to 3 hours."),
        s("Kiyomizu-dera, Kyoto", "11:00", "12:30", "Walk down through Sannenzaka and Ninenzaka afterwards."),
        s("Gion, Kyoto", "17:30", "19:30", "Hanamikoji Street at dusk. Do not photograph maiko without permission."),
      ],
      [
        s("Arashiyama Bamboo Grove, Kyoto", "07:30", "08:30", "Crowds build fast after 9am."),
        s("Tenryu-ji, Kyoto", "08:45", "10:00", "UNESCO Zen temple with a pond garden next to the grove."),
        s("Iwatayama Monkey Park, Kyoto", "10:30", "12:00", "Short uphill hike with a city view at the top."),
      ],
      [
        s("Kinkaku-ji, Kyoto", "09:00", "10:00", "The Golden Pavilion. Best on a clear morning."),
        s("Ryoan-ji, Kyoto", "10:30", "11:30", "The famous rock garden. Sit for a while."),
        s("Nishiki Market, Kyoto", "13:00", "15:00", "Kyoto's kitchen. Eating while walking is discouraged, so eat at the stall."),
      ],
    ],
  },
  {
    slug: "jp-tokyo",
    title: "Tokyo First-Timer's Classic",
    destination: "Tokyo, Japan",
    days: [
      [
        s("Senso-ji, Asakusa, Tokyo", "08:00", "09:30", "Nakamise shopping street opens around 10."),
        s("Tokyo Skytree", "10:30", "12:00", "Book a time slot online. Clear mornings sometimes show Mt Fuji."),
        s("Akihabara, Tokyo", "14:00", "17:00", "Electronics, anime and retro game shops."),
      ],
      [
        s("Meiji Jingu, Tokyo", "08:30", "09:30", "Forest shrine next to Harajuku."),
        s("Takeshita Street, Harajuku, Tokyo", "10:00", "11:00", "Street fashion and crepes."),
        s("Shibuya Scramble Crossing, Tokyo", "17:00", "18:00", "Watch it from above at Shibuya Sky or a station-side cafe."),
        s("Shinjuku Omoide Yokocho, Tokyo", "19:00", "21:00", "Tiny yakitori alleys. Many places are cash only."),
      ],
      [
        s("Tsukiji Outer Market, Tokyo", "08:00", "10:00", "Breakfast sushi and tamagoyaki."),
        s("teamLab Planets TOKYO", "11:00", "13:00", "Book ahead. You walk barefoot through water."),
        s("Odaiba Seaside Park, Tokyo", "16:00", "18:30", "Rainbow Bridge views at sunset."),
      ],
    ],
  },
  {
    slug: "jp-osaka-nara",
    title: "Osaka Street Food and a Day in Nara",
    destination: "Osaka, Japan",
    days: [
      [
        s("Osaka Castle", "09:00", "11:00", "The park is lovely even if you skip the museum inside."),
        s("Kuromon Ichiba Market, Osaka", "12:00", "13:30", "Grilled seafood and wagyu skewers."),
        s("Shinsekai, Osaka", "15:00", "17:00", "Retro district with kushikatsu. No double-dipping the sauce."),
        s("Dotonbori, Osaka", "18:30", "21:30", "Takoyaki, okonomiyaki and the Glico sign."),
      ],
      [
        s("Nara Park", "09:00", "10:30", "Deer bow for shika senbei crackers. Hold them up, then feed."),
        s("Todai-ji, Nara", "10:30", "12:00", "Giant bronze Buddha in one of the largest wooden halls."),
        s("Kasuga Taisha, Nara", "12:30", "13:30", "Thousands of stone and bronze lanterns."),
        s("Naramachi, Nara", "14:00", "16:00", "Old merchant quarter with machiya houses."),
      ],
    ],
  },
  {
    slug: "jp-hokkaido",
    title: "Hokkaido Summer: Sapporo, Otaru and Furano",
    destination: "Sapporo, Japan",
    radiusKm: 160,
    days: [
      [
        s("Odori Park, Sapporo", "09:00", "10:00", "Central park strip running through the city."),
        s("Sapporo Beer Museum", "10:30", "12:00", "History tour plus tasting."),
        s("Nijo Market, Sapporo", "12:30", "13:30", "Kaisendon seafood rice bowls."),
        s("Mount Moiwa Ropeway, Sapporo", "18:00", "20:00", "One of Japan's classic night views."),
      ],
      [
        s("Otaru Canal", "09:30", "11:00", "Stone warehouses along the canal. About 40 minutes by train from Sapporo."),
        s("Otaru Music Box Museum", "11:15", "12:15", "The steam clock stands just outside."),
        s("Sakaimachi Street, Otaru", "12:30", "15:00", "Glassworks and LeTAO desserts."),
      ],
      [
        s("Farm Tomita, Furano", "09:00", "11:00", "Lavender peaks in July. Free entry."),
        s("Shirogane Blue Pond, Biei", "12:30", "13:30", "Colour changes with weather and season."),
        s("Shikisai no Oka, Biei", "14:00", "16:00", "Rolling flower fields."),
      ],
    ],
  },
  {
    slug: "jp-hakone-fuji",
    title: "Hakone and Mt Fuji Five Lakes",
    destination: "Hakone, Japan",
    radiusKm: 120,
    days: [
      [
        s("Hakone Open-Air Museum", "09:30", "11:30", "Sculpture park with a foot bath and the Picasso pavilion."),
        s("Owakudani, Hakone", "12:30", "13:30", "Volcanic valley. Try the black eggs."),
        s("Lake Ashi Pirate Ship, Hakone", "14:00", "15:00", "Cruise to Moto-Hakone."),
        s("Hakone Shrine", "15:15", "16:15", "The red torii in the lake is the iconic shot."),
      ],
      [
        s("Chureito Pagoda, Fujiyoshida", "07:30", "09:00", "About 400 steps. The classic pagoda-and-Fuji frame."),
        s("Oishi Park, Kawaguchiko", "10:00", "11:30", "Lakeside flower garden with Fuji views."),
        s("Oshino Hakkai", "12:30", "14:00", "Spring-fed ponds in a small village."),
      ],
    ],
  },

  // -------------------------------------------------------------- Elsewhere
  {
    slug: "kr-seoul",
    title: "Seoul Palaces, Markets and Neighbourhoods",
    destination: "Seoul, South Korea",
    days: [
      [
        s("Gyeongbokgung Palace, Seoul", "09:30", "11:30", "Entry is free if you wear hanbok. Guard change runs mid-morning."),
        s("Bukchon Hanok Village, Seoul", "12:00", "13:30", "Residents live here, so keep your voice down."),
        s("Insadong, Seoul", "14:00", "16:00", "Tea houses and craft shops."),
        s("Gwangjang Market, Seoul", "18:00", "20:00", "Bindaetteok and mayak gimbap."),
      ],
      [
        s("Changdeokgung Palace, Seoul", "09:30", "11:30", "The Secret Garden requires a guided tour. Book it."),
        s("N Seoul Tower", "16:00", "18:30", "Cable car or a walk up Namsan."),
        s("Myeongdong, Seoul", "19:00", "21:00", "Street food stalls and cosmetics shops."),
      ],
      [
        s("Hongdae, Seoul", "13:00", "16:00", "Street performers and indie shops."),
        s("Hangang Park Yeouido, Seoul", "18:00", "20:00", "Order fried chicken to the riverbank like locals do."),
      ],
    ],
  },
  {
    slug: "kr-busan",
    title: "Busan Coast in Two Days",
    destination: "Busan, South Korea",
    days: [
      [
        s("Haedong Yonggungsa Temple, Busan", "08:30", "10:00", "Seaside temple on the rocks. Arrive before crowds."),
        s("Haeundae Beach, Busan", "11:00", "13:00", "Walk the Dongbaekseom island trail next to it."),
        s("Haeundae Blueline Park, Busan", "14:00", "16:00", "Sky capsule train along the coast. Book ahead."),
        s("The Bay 101, Busan", "19:00", "20:30", "Night skyline over Marine City."),
      ],
      [
        s("Gamcheon Culture Village, Busan", "09:30", "11:30", "Hillside pastel houses. Pick up the stamp map."),
        s("Jagalchi Fish Market, Busan", "12:00", "13:30", "Pick seafood downstairs and they cook it upstairs."),
        s("BIFF Square, Busan", "14:00", "15:00", "Try ssiat hotteok, the seed-filled pancake."),
        s("Gwangalli Beach, Busan", "19:00", "21:00", "Gwangan Bridge lights at night."),
      ],
    ],
  },
  {
    slug: "tw-taipei",
    title: "Taipei, Jiufen and Night Markets",
    destination: "Taipei, Taiwan",
    radiusKm: 60,
    days: [
      [
        s("Chiang Kai-shek Memorial Hall, Taipei", "09:00", "10:30", "Guard change on the hour."),
        s("Longshan Temple, Taipei", "11:00", "12:00", "Active temple. Watch the fortune-telling blocks."),
        s("Din Tai Fung Xinyi, Taipei", "12:30", "13:30", "Take a queue number, then wander nearby."),
        s("Taipei 101 Observatory", "16:30", "18:30", "Go around sunset to see day turn into city lights."),
      ],
      [
        s("Jiufen Old Street", "10:00", "13:00", "Hillside lantern street. Weekday mornings are calmer."),
        s("Shifen Old Street", "14:00", "16:00", "Release a sky lantern over the railway tracks."),
        s("Raohe Street Night Market, Taipei", "19:00", "21:00", "Black pepper buns at the entrance gate."),
      ],
      [
        s("Elephant Mountain Hiking Trail, Taipei", "07:00", "08:30", "Short, steep climb with a Taipei 101 view."),
        s("Beitou Hot Spring Museum, Taipei", "11:00", "12:00", "Then soak at a public hot spring nearby."),
        s("Shilin Night Market, Taipei", "18:30", "21:00", "Largest night market. Try the big fried chicken."),
      ],
    ],
  },
  {
    slug: "hk-hong-kong",
    title: "Hong Kong Island and Kowloon",
    destination: "Hong Kong",
    days: [
      [
        s("The Peak Tram, Hong Kong", "08:30", "10:00", "Go early to skip the queue."),
        s("Man Mo Temple, Hong Kong", "11:00", "11:45", "Incense coils hang from the ceiling."),
        s("PMQ, Hong Kong", "12:00", "13:30", "Design studios in former police quarters."),
        s("Tim Ho Wan Sham Shui Po", "14:00", "15:00", "Budget Michelin dim sum. Order the baked BBQ pork buns."),
      ],
      [
        s("Star Ferry Pier Tsim Sha Tsui", "10:00", "10:30", "Cheapest harbour cruise in the world."),
        s("Tian Tan Buddha, Lantau", "12:00", "14:30", "Take the Ngong Ping 360 cable car up."),
        s("Temple Street Night Market, Hong Kong", "19:00", "21:00", "Claypot rice and fortune tellers."),
        s("Avenue of Stars, Hong Kong", "20:00", "20:30", "Symphony of Lights starts at 8pm."),
      ],
    ],
  },
  {
    slug: "sg-singapore",
    title: "Singapore Gardens and Hawker Classics",
    destination: "Singapore",
    days: [
      [
        s("Gardens by the Bay, Singapore", "09:00", "12:00", "Cloud Forest and Flower Dome are indoor, a good escape from the heat."),
        s("Lau Pa Sat, Singapore", "12:30", "13:30", "Satay street opens in the evening."),
        s("Marina Bay Sands SkyPark", "17:30", "19:00", "Stay for the Supertree Garden Rhapsody light show."),
      ],
      [
        s("Chinatown Complex Food Centre, Singapore", "09:00", "10:00", "Hundreds of hawker stalls. Look for the long queues."),
        s("Buddha Tooth Relic Temple, Singapore", "10:15", "11:15", "Free entry, modest dress."),
        s("Haji Lane, Singapore", "14:00", "16:00", "Street art and indie boutiques in Kampong Glam."),
        s("Sultan Mosque, Singapore", "16:00", "16:45", "Robes are provided at the entrance."),
      ],
    ],
  },
  {
    slug: "id-bali",
    title: "Bali: Ubud Rice Terraces to Uluwatu Cliffs",
    destination: "Ubud, Bali, Indonesia",
    radiusKm: 80,
    days: [
      [
        s("Sacred Monkey Forest Sanctuary, Ubud", "09:00", "10:30", "Secure sunglasses and bags. The monkeys grab things."),
        s("Ubud Art Market", "11:00", "12:30", "Bargaining is expected."),
        s("Campuhan Ridge Walk, Ubud", "16:30", "18:00", "Easy ridge trail at golden hour."),
      ],
      [
        s("Tegallalang Rice Terrace, Bali", "07:30", "09:30", "Beat the heat and the crowds."),
        s("Tirta Empul Temple, Bali", "10:30", "12:00", "Holy spring purification. A sarong is provided."),
        s("Tegenungan Waterfall, Bali", "14:00", "15:30", "Steep stairs down to swim."),
      ],
      [
        s("Padang Padang Beach, Bali", "13:00", "16:00", "Small cove reached through a rock passage."),
        s("Uluwatu Temple, Bali", "16:30", "18:00", "Kecak fire dance at sunset. Get seats early."),
      ],
    ],
  },
  {
    slug: "vn-hanoi-halong",
    title: "Hanoi Old Quarter and Ha Long Bay",
    destination: "Hanoi, Vietnam",
    radiusKm: 200,
    days: [
      [
        s("Hoan Kiem Lake, Hanoi", "07:00", "08:00", "Locals doing tai chi at dawn."),
        s("Temple of Literature, Hanoi", "09:00", "10:30", "Vietnam's first university, built in 1070."),
        s("Hanoi Train Street", "15:00", "16:00", "Access changes often. Follow local rules and cafe staff."),
        s("Bia Hoi Corner, Hanoi", "19:00", "21:00", "Fresh beer on tiny plastic stools."),
      ],
      [
        s("Ha Long Bay", "11:00", "17:00", "Take a day cruise or stay overnight. Kayak into the lagoons."),
        s("Sung Sot Cave, Ha Long", "13:00", "14:00", "Largest cave on the standard cruise routes."),
      ],
      [
        s("Ho Chi Minh Mausoleum, Hanoi", "08:00", "09:30", "Closed some afternoons and seasons. Strict dress code."),
        s("Hanoi Old Quarter", "10:00", "12:00", "Streets named after the trades once sold there."),
        s("Bun Cha Huong Lien, Hanoi", "12:00", "13:00", "Bun cha, famous as the Obama and Bourdain meal."),
      ],
    ],
  },
  {
    slug: "la-luang-prabang",
    title: "Luang Prabang Slow Days",
    destination: "Luang Prabang, Laos",
    days: [
      [
        s("Wat Xieng Thong, Luang Prabang", "08:00", "09:30", "The finest temple in town, with a tree-of-life mosaic."),
        s("Royal Palace Museum, Luang Prabang", "10:00", "11:30", "No shoulders or knees showing, and no photos inside."),
        s("Mount Phousi, Luang Prabang", "17:00", "18:30", "Around 330 steps to a sunset over the Mekong."),
        s("Luang Prabang Night Market", "18:45", "21:00", "Quiet, relaxed handicraft market."),
      ],
      [
        s("Kuang Si Falls, Luang Prabang", "09:00", "13:00", "Turquoise pools. The bear rescue centre is at the entrance."),
        s("Utopia, Luang Prabang", "16:00", "18:30", "Riverside garden bar with a view of the Nam Khan."),
      ],
    ],
  },
  {
    slug: "kh-siem-reap",
    title: "Angkor Temples from Siem Reap",
    destination: "Siem Reap, Cambodia",
    days: [
      [
        s("Angkor Wat", "05:00", "08:30", "Sunrise over the reflecting pools. Buy the pass the day before."),
        s("Bayon Temple, Angkor Thom", "09:00", "10:30", "Over 200 serene stone faces."),
        s("Ta Prohm", "11:00", "12:30", "Tree roots swallowing the ruins."),
        s("Pub Street, Siem Reap", "19:00", "21:00", "Lively dinner street."),
      ],
      [
        s("Banteay Srei", "08:00", "09:30", "Intricate pink sandstone carvings, about 40 minutes out."),
        s("Preah Khan, Angkor", "10:30", "12:00", "Quieter than the headline temples."),
        s("Phare, The Cambodian Circus", "20:00", "21:30", "Acrobatics that support a local arts school."),
      ],
    ],
  },
  {
    slug: "fr-paris",
    title: "Paris in Three Days",
    destination: "Paris, France",
    days: [
      [
        s("Louvre Museum, Paris", "09:00", "12:30", "Book a timed ticket. Enter through the Carrousel entrance."),
        s("Jardin des Tuileries, Paris", "12:30", "13:30", "Picnic between the Louvre and Concorde."),
        s("Musée d'Orsay, Paris", "14:30", "17:00", "Impressionists and the giant clock window."),
        s("Pont Neuf, Paris", "20:00", "21:00", "Sunset along the Seine."),
      ],
      [
        s("Sainte-Chapelle, Paris", "09:00", "10:00", "Stained glass is best on a sunny morning."),
        s("Notre-Dame de Paris", "10:15", "11:15", "Reopened after restoration. Reserve free entry online."),
        s("Le Marais, Paris", "12:00", "15:00", "Falafel on Rue des Rosiers and Place des Vosges."),
        s("Eiffel Tower", "19:00", "21:30", "It sparkles for five minutes on the hour after dark."),
      ],
      [
        s("Sacré-Cœur Basilica, Paris", "09:00", "10:00", "Walk up through Montmartre's backstreets."),
        s("Place du Tertre, Paris", "10:00", "11:00", "Painters' square."),
        s("Palace of Versailles", "13:00", "18:00", "RER C from central Paris. The gardens are huge, so rent a cart or bike."),
      ],
    ],
  },
  {
    slug: "it-rome",
    title: "Rome: Ancient City to Vatican",
    destination: "Rome, Italy",
    days: [
      [
        s("Colosseum, Rome", "08:30", "10:30", "The combined ticket covers the Forum and Palatine. Book ahead."),
        s("Roman Forum, Rome", "10:30", "12:30", "Bring water. There is little shade."),
        s("Trastevere, Rome", "19:00", "22:00", "Cacio e pepe in a trattoria."),
      ],
      [
        s("Vatican Museums", "08:00", "11:30", "The Sistine Chapel is at the end. No photos inside."),
        s("St. Peter's Basilica", "12:00", "13:30", "Climb the dome for the best view in Rome."),
        s("Castel Sant'Angelo, Rome", "15:00", "16:30", "Rooftop terrace over the Tiber."),
      ],
      [
        s("Trevi Fountain, Rome", "07:30", "08:00", "Only calm before 8am. Toss a coin over your left shoulder."),
        s("Pantheon, Rome", "09:00", "09:45", "Look up at the oculus."),
        s("Piazza Navona, Rome", "10:00", "11:00", "Bernini's Fountain of the Four Rivers."),
        s("Spanish Steps, Rome", "17:00", "18:00", "Sitting on the steps is not allowed."),
      ],
    ],
  },
  {
    slug: "es-barcelona",
    title: "Barcelona Gaudí and the Gothic Quarter",
    destination: "Barcelona, Spain",
    days: [
      [
        s("Sagrada Família, Barcelona", "09:00", "11:00", "Timed tickets sell out. Morning light hits the Nativity facade."),
        s("Casa Batlló, Barcelona", "12:00", "13:30", "Gaudí's dragon-back rooftop."),
        s("Casa Milà, Barcelona", "14:00", "15:30", "La Pedrera, with rooftop chimneys."),
        s("El Born, Barcelona", "20:00", "22:30", "Tapas bars. Dinner starts late here."),
      ],
      [
        s("Park Güell, Barcelona", "08:30", "10:30", "The monumental zone needs a timed ticket."),
        s("Barcelona Cathedral", "11:30", "12:30", "Go up to the roof terrace."),
        s("La Boqueria Market, Barcelona", "12:45", "14:00", "Eat at the counter bars in the back."),
        s("Bunkers del Carmel, Barcelona", "19:00", "20:30", "Free 360-degree sunset view."),
      ],
    ],
  },
  {
    slug: "nl-amsterdam",
    title: "Amsterdam Canals and Museums",
    destination: "Amsterdam, Netherlands",
    days: [
      [
        s("Rijksmuseum, Amsterdam", "09:00", "12:00", "Night Watch gallery first, before it fills."),
        s("Van Gogh Museum, Amsterdam", "13:00", "15:00", "Timed tickets only."),
        s("Vondelpark, Amsterdam", "15:30", "16:30", "Watch for bikes. They have the right of way."),
        s("Jordaan, Amsterdam", "18:00", "21:00", "Canal-side dinner and brown cafés."),
      ],
      [
        s("Anne Frank House, Amsterdam", "09:00", "10:30", "Tickets release online weeks ahead and go fast."),
        s("Westerkerk, Amsterdam", "10:30", "11:15", "Climb the tower for canal views."),
        s("Albert Cuyp Market, Amsterdam", "12:00", "13:30", "Fresh stroopwafels."),
        s("A'DAM Lookout, Amsterdam", "17:00", "18:30", "Free ferry from behind Centraal Station. There is a swing over the edge."),
      ],
    ],
  },
  {
    slug: "ch-swiss-alps",
    title: "Swiss Alps: Lucerne and Interlaken",
    destination: "Interlaken, Switzerland",
    radiusKm: 120,
    days: [
      [
        s("Chapel Bridge, Lucerne", "09:00", "10:00", "Wooden bridge with painted panels."),
        s("Lion Monument, Lucerne", "10:15", "10:45", "Mark Twain's saddest stone."),
        s("Mount Pilatus", "12:00", "16:00", "Take the world's steepest cogwheel railway up and the cable car down."),
      ],
      [
        s("Harder Kulm, Interlaken", "09:00", "11:00", "Funicular to a view over both lakes."),
        s("Lauterbrunnen Valley", "12:00", "15:00", "Staubbach Falls drops straight into the village."),
        s("Trümmelbach Falls, Lauterbrunnen", "15:15", "16:30", "Glacier waterfalls inside the mountain."),
      ],
      [
        s("Jungfraujoch", "08:00", "14:00", "Top of Europe station. Check the summit webcam before buying tickets."),
        s("Grindelwald First", "15:00", "17:30", "Cliff Walk and the gentle Bachalpsee lake hike."),
      ],
    ],
  },
  {
    slug: "gb-london",
    title: "London Landmarks and Markets",
    destination: "London, United Kingdom",
    days: [
      [
        s("Westminster Abbey, London", "09:30", "11:00", "Closed to tourists on Sundays."),
        s("Buckingham Palace, London", "11:00", "11:45", "Check the Changing the Guard schedule. It is not daily."),
        s("British Museum, London", "13:30", "16:30", "Free. Rosetta Stone in Room 4."),
        s("Covent Garden, London", "18:00", "20:00", "Street performers in the piazza."),
      ],
      [
        s("Tower of London", "09:00", "11:30", "Crown Jewels first, before the queue builds."),
        s("Tower Bridge, London", "11:45", "12:30", "Glass-floor walkway."),
        s("Borough Market, London", "12:45", "14:00", "Closed Mondays for the full market."),
        s("Tate Modern, London", "14:30", "16:30", "Free, with a viewing level on the tenth floor."),
      ],
      [
        s("Camden Market, London", "10:00", "12:30", "Street food from everywhere."),
        s("Primrose Hill, London", "13:00", "14:00", "Skyline view from a green hill."),
        s("Notting Hill, London", "15:00", "17:00", "Portobello Road is busiest on Saturdays."),
      ],
    ],
  },
  {
    slug: "is-south-coast",
    title: "Iceland South Coast Road Trip",
    destination: "Vík, Iceland",
    radiusKm: 260,
    days: [
      [
        s("Þingvellir National Park", "09:00", "11:00", "Walk between the tectonic plates."),
        s("Geysir, Iceland", "12:00", "13:00", "Strokkur erupts every few minutes. Stand upwind."),
        s("Gullfoss", "13:30", "14:30", "Waterproof jacket for the spray."),
      ],
      [
        s("Seljalandsfoss", "09:00", "10:00", "You can walk behind the falls. It is slippery."),
        s("Skógafoss", "10:45", "11:45", "527 steps to the top viewpoint."),
        s("Reynisfjara Black Sand Beach", "13:30", "15:00", "Sneaker waves are deadly. Stay well back from the water."),
        s("Vík í Mýrdal Church", "15:30", "16:00", "Hilltop church over the village."),
      ],
      [
        s("Fjaðrárgljúfur Canyon", "09:30", "10:30", "Stay on the marked path. It closes in thaw season."),
        s("Jökulsárlón Glacier Lagoon", "12:30", "14:30", "Icebergs calving from Breiðamerkurjökull."),
        s("Diamond Beach, Iceland", "14:30", "15:30", "Ice chunks on black sand across the road from the lagoon."),
      ],
    ],
  },
  {
    slug: "tr-istanbul",
    title: "Istanbul Between Two Continents",
    destination: "Istanbul, Turkey",
    days: [
      [
        s("Hagia Sophia, Istanbul", "09:00", "10:30", "An active mosque. Visitors are not admitted during prayer times, and women cover their hair."),
        s("Blue Mosque, Istanbul", "10:45", "11:30", "Enter through the visitor entrance."),
        s("Basilica Cistern, Istanbul", "11:45", "12:45", "The Medusa heads are at the far end."),
        s("Topkapı Palace, Istanbul", "14:00", "17:00", "The Harem needs a separate ticket, and it is worth it."),
      ],
      [
        s("Grand Bazaar, Istanbul", "09:30", "11:30", "Closed on Sundays."),
        s("Süleymaniye Mosque, Istanbul", "12:00", "13:00", "Terrace view over the Golden Horn."),
        s("Galata Tower, Istanbul", "16:00", "17:00", "Go before sunset. The queue grows later."),
        s("Karaköy, Istanbul", "18:00", "21:00", "Fish sandwiches and meyhane dinner."),
      ],
    ],
  },
  {
    slug: "us-new-york",
    title: "New York City Essentials",
    destination: "New York, NY, USA",
    days: [
      [
        s("Statue of Liberty", "09:00", "12:00", "Book the official ferry from Battery Park. Crown tickets sell out months ahead."),
        s("9/11 Memorial & Museum, New York", "13:00", "15:00", "The pools are free. The museum is ticketed."),
        s("Brooklyn Bridge", "17:00", "18:30", "Walk from Manhattan toward Brooklyn at sunset."),
        s("DUMBO, Brooklyn", "18:30", "20:00", "Manhattan Bridge framed on Washington Street."),
      ],
      [
        s("Central Park, New York", "08:00", "10:30", "Bethesda Terrace to Bow Bridge."),
        s("The Metropolitan Museum of Art", "10:30", "13:30", "The Temple of Dendur hall is a highlight."),
        s("Top of the Rock, New York", "17:30", "19:00", "The only view that includes the Empire State Building."),
        s("Times Square, New York", "20:00", "21:00", "Best seen once, at night."),
      ],
      [
        s("The High Line, New York", "09:00", "10:30", "Elevated park from Gansevoort Street north."),
        s("Chelsea Market, New York", "10:30", "12:00", "Tacos, lobster rolls and doughnuts."),
        s("Grand Central Terminal, New York", "14:00", "15:00", "Whispering gallery by the Oyster Bar."),
      ],
    ],
  },
  {
    slug: "us-pch",
    title: "California Pacific Coast Highway: SF to Big Sur",
    destination: "Monterey, CA, USA",
    radiusKm: 220,
    days: [
      [
        s("Golden Gate Bridge Welcome Center", "08:30", "10:00", "Fog often clears by late morning."),
        s("Pigeon Point Lighthouse", "12:00", "13:00", "Classic Highway 1 lighthouse."),
        s("Santa Cruz Beach Boardwalk", "14:30", "16:30", "Seaside amusement park since 1907."),
      ],
      [
        s("Monterey Bay Aquarium", "09:30", "12:30", "Kelp forest tank and sea otter feedings."),
        s("17-Mile Drive, Pebble Beach", "13:30", "15:30", "Toll road. The Lone Cypress is the icon."),
        s("Carmel-by-the-Sea", "16:00", "18:30", "Fairytale cottages and a white-sand beach."),
      ],
      [
        s("Bixby Creek Bridge, Big Sur", "09:00", "09:45", "Pull-outs on the north side give the classic view."),
        s("Pfeiffer Big Sur State Park", "10:30", "12:30", "Redwood trails to Pfeiffer Falls."),
        s("McWay Falls, Big Sur", "13:30", "14:30", "Waterfall onto the beach. Short viewpoint trail."),
      ],
    ],
  },
  {
    slug: "au-sydney",
    title: "Sydney Harbour and Beaches",
    destination: "Sydney, Australia",
    radiusKm: 120,
    days: [
      [
        s("Sydney Opera House", "09:00", "10:30", "The one-hour guided tour is worth it."),
        s("Royal Botanic Garden Sydney", "10:30", "12:00", "Walk to Mrs Macquarie's Chair for the harbour postcard view."),
        s("The Rocks, Sydney", "12:30", "14:30", "Weekend markets and historic pubs."),
        s("Sydney Harbour Bridge Pylon Lookout", "16:30", "17:30", "The cheaper alternative to the BridgeClimb."),
      ],
      [
        s("Bondi Beach", "08:00", "09:30", "Swim between the red-and-yellow flags."),
        s("Bondi to Coogee Coastal Walk", "09:30", "12:00", "About 6 km of cliffs and ocean pools."),
        s("Manly Ferry, Circular Quay", "15:00", "15:30", "Scenic harbour ferry ride."),
        s("Manly Beach", "15:30", "18:00", "Fish and chips on the Corso."),
      ],
    ],
  },
];
