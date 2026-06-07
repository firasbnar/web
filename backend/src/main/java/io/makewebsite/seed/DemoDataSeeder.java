package io.makewebsite.seed;

import io.makewebsite.entity.*;
import io.makewebsite.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

@Component
@RequiredArgsConstructor
@Slf4j
public class DemoDataSeeder implements CommandLineRunner {

    private final BoutiqueRepository boutiqueRepository;
    private final UserRepository userRepository;
    private final TenantRepository tenantRepository;
    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final CustomerRepository customerRepository;
    private final OrderRepository orderRepository;
    private final PasswordEncoder passwordEncoder;

    private static final String BOUTIQUE_SLUG = "tech-lifestyle-store";

    @Override
    @Transactional
    public void run(String... args) {
        if (boutiqueRepository.existsBySlug(BOUTIQUE_SLUG)) {
            log.info("Demo boutique '{}' already exists, skipping seed.", BOUTIQUE_SLUG);
            return;
        }

        log.info("Seeding demo data...");

        Tenant tenant = tenantRepository.save(Tenant.builder()
                .name("Demo Tenant")
                .active(true)
                .build());

        User user = userRepository.save(User.builder()
                .fullName("Demo Owner")
                .email("demo@techstore.com")
                .passwordHash(passwordEncoder.encode("password123"))
                .tenant(tenant)
                .role("OWNER")
                .enabled(true)
                .emailVerified(true)
                .language("fr")
                .build());

        Boutique boutique = boutiqueRepository.save(Boutique.builder()
                .name("Tech & Lifestyle Store")
                .slug(BOUTIQUE_SLUG)
                .user(user)
                .tenant(tenant)
                .description("Votre boutique de référence pour les produits tech et lifestyle en Tunisie")
                .currency("TND")
                .language("fr")
                .country("Tunisie")
                .city("Tunis")
                .email("contact@techstore.tn")
                .phone("+216 70 000 000")
                .isActive(true)
                .isPublished(true)
                .storeStatus("ACTIVE")
                .build());

        List<Category> categories = createCategories(boutique);
        List<Product> products = createProducts(boutique, categories);
        List<Customer> customers = createCustomers(boutique);
        createOrders(boutique, products, customers);

        log.info("Demo data seeded: boutique={}, categories={}, products={}, customers={}, orders={}",
                boutique.getSlug(), categories.size(), products.size(),
                customers.size(), orderRepository.countByBoutiqueId(boutique.getId()));
    }

    private List<Category> createCategories(Boutique boutique) {
        List<Category> categories = new ArrayList<>();
        String[][] catData = {
                {"Smartphones", "smartphones"},
                {"Laptops & Ordinateurs", "laptops"},
                {"Tablettes", "tablettes"},
                {"Casques & Écouteurs", "casques"},
                {"Montres Connectées", "montres"},
                {"Appareils Photo", "appareils-photo"},
                {"Gaming", "gaming"},
                {"Accessoires", "accessoires"},
                {"Enceintes", "enceintes"},
                {"Imprimantes", "imprimantes"},
        };
        for (int i = 0; i < catData.length; i++) {
            Category cat = categoryRepository.save(Category.builder()
                    .boutique(boutique)
                    .name(catData[i][0])
                    .slug(catData[i][1])
                    .sortOrder(i)
                    .build());
            categories.add(cat);
        }
        return categories;
    }

    private List<Product> createProducts(Boutique boutique, List<Category> categories) {
        List<Product> products = new ArrayList<>();
        Random rnd = ThreadLocalRandom.current();

        String[][] smartphones = {
                {"iPhone 15 Pro Max 256GB", "4990.00", "Dernier smartphone Apple avec puce A17 Pro, écran 6.7\" Super Retina XDR et appareil photo 48MP", "10"},
                {"Samsung Galaxy S24 Ultra 512GB", "4590.00", "Smartphone Samsung avec Galaxy AI, écran 6.8\" Dynamic AMOLED 2X et S Pen intégré", "8"},
                {"Xiaomi Redmi Note 13 Pro 256GB", "1290.00", "Smartphone Xiaomi avec appareil photo 200MP, écran AMOLED 6.67\" 120Hz", "25"},
                {"Huawei P60 Pro 256GB", "3490.00", "Smartphone Huawei avec appareil photo XMAGE, écran LTPO 6.67\" et charge rapide 88W", "5"},
                {"Oppo Reno 11 5G 256GB", "1490.00", "Smartphone Oppo avec appareil photo portrait 50MP et charge SUPERVOOC 67W", "15"},
                {"Google Pixel 8 Pro 128GB", "3990.00", "Smartphone Google avec IA intégrée, écran Super Actua 6.7\" et appareil photo 50MP", "4"},
                {"OnePlus 12 256GB", "3290.00", "Smartphone OnePlus avec Snapdragon 8 Gen 3, écran 6.82\" 120Hz et charge 100W", "7"},
                {"Realme GT 5 256GB", "1990.00", "Smartphone Realme avec Snapdragon 8 Gen 2, écran 6.74\" 144Hz et charge 240W", "12"},
                {"Samsung Galaxy A55 128GB", "990.00", "Smartphone Samsung Galaxy A avec écran Super AMOLED 6.6\" et batterie 5000mAh", "30"},
                {"Tecno Camon 20 Pro 256GB", "890.00", "Smartphone Tecno avec appareil photo 108MP et écran AMOLED 6.67\" 120Hz", "20"},
        };

        String[][] laptops = {
                {"MacBook Pro 16\" M3 Pro 512GB", "8990.00", "Ordinateur portable Apple avec puce M3 Pro, écran Liquid Retina XDR 16.2\" et 18h d'autonomie", "6"},
                {"Dell XPS 15 Intel i7 16GB 512GB", "5490.00", "PC portable Dell XPS avec Intel Core i7-13700H, écran InfinityEdge OLED 15.6\"", "4"},
                {"HP Spectre x360 i7 16GB 1TB", "6290.00", "PC portable HP convertible 2-en-1 avec Intel Core i7, écran tactile OLED 16\" et stylet inclus", "3"},
                {"Lenovo ThinkPad X1 Carbon i7 16GB", "5890.00", "PC portable Lenovo ThinkPad avec Intel Core i7-1365U, écran 14\" WQUXGA et poids 1.12kg", "5"},
                {"ASUS ROG Zephyrus G14 Ryzen 9 RTX 4060", "6490.00", "PC portable gaming ASUS avec AMD Ryzen 9 7940HS, NVIDIA RTX 4060 et écran QHD 14\" 165Hz", "7"},
                {"Acer Swift 3 i5 8GB 256GB", "2490.00", "PC portable Acer Swift avec Intel Core i5-1335U, écran 14\" Full HD et poids 1.25kg", "10"},
                {"Microsoft Surface Laptop 5 i5 8GB 256GB", "3990.00", "PC portable Microsoft Surface avec Intel Core i5-1235U, écran tactile 13.5\" PixelSense", "4"},
                {"Xiaomi Book Pro 14 i5 16GB 512GB", "3290.00", "PC portable Xiaomi avec Intel Core i5-12450H, écran 2.8K 14\" OLED 120Hz", "8"},
                {"Lenovo IdeaPad 3 i3 8GB 256GB", "1490.00", "PC portable Lenovo IdeaPad avec Intel Core i3-1215U, écran 15.6\" Full HD", "20"},
                {"HP Pavilion 15 i5 8GB 512GB", "2690.00", "PC portable HP Pavilion avec Intel Core i5-1334U, écran 15.6\" Full HD IPS", "12"},
        };

        String[][] tablettes = {
                {"iPad Pro 12.9\" M2 256GB", "4990.00", "Tablette Apple iPad Pro avec puce M2, écran Liquid Retina XDR 12.9\" et compatibilité Apple Pencil", "5"},
                {"Samsung Galaxy Tab S9 Ultra 256GB", "4290.00", "Tablette Samsung Galaxy Tab S9 Ultra avec écran Dynamic AMOLED 2X 14.6\", S Pen et IP68", "4"},
                {"iPad Air 10.9\" M1 64GB", "2990.00", "Tablette Apple iPad Air avec puce M1, écran Liquid Retina 10.9\" et Touch ID", "10"},
                {"Huawei MatePad Pro 12.6 256GB", "3190.00", "Tablette Huawei MatePad Pro avec écran OLED 12.6\", Kirin 9000E et stylet M-Pencil", "3"},
                {"Lenovo Tab P12 Pro 256GB", "2190.00", "Tablette Lenovo Tab P12 Pro avec écran AMOLED 12.6\" 120Hz et MediaTek Kompanio 1300T", "6"},
                {"Samsung Galaxy Tab A9+ 128GB", "990.00", "Tablette Samsung Galaxy Tab A9+ avec écran TFT 11\" 90Hz et quatre haut-parleurs", "18"},
                {"Xiaomi Pad 6 128GB", "1290.00", "Tablette Xiaomi Pad 6 avec écran LCD 11\" 144Hz, Snapdragon 870 et batterie 8840mAh", "15"},
                {"Amazon Fire HD 10 64GB", "590.00", "Tablette Amazon Fire HD 10 avec écran 10.1\" 1080p et processeur octa-core 2.0 GHz", "25"},
                {"Realme Pad 2 128GB", "790.00", "Tablette Realme Pad 2 avec écran 2K 11.5\" 120Hz, MediaTek Helio G99 et batterie 8360mAh", "12"},
                {"Microsoft Surface Pro 9 i5 256GB", "5990.00", "Tablette Microsoft Surface Pro 9 avec Intel Core i5-1235U, écran 13\" 2880x1920 120Hz", "3"},
        };

        String[][] casques = {
                {"Sony WH-1000XM5 Wireless", "1290.00", "Casque sans fil Sony avec réduction de bruit active, 30h d'autonomie et cas pliable", "15"},
                {"Apple AirPods Max", "2590.00", "Casque Apple AirPods Max avec réduction de bruit active, audio spatial et design aluminium", "7"},
                {"Bose QuietComfort Ultra", "1490.00", "Casque Bose QuietComfort Ultra avec réduction de bruit, audio spatial et CustomTune", "10"},
                {"Samsung Galaxy Buds2 Pro", "590.00", "Écouteurs Samsung Galaxy Buds2 Pro avec audio 24-bit, ANC et IPX7", "20"},
                {"JBL Tune 770NC", "390.00", "Casque JBL Tune 770NC avec réduction de bruit adaptive et son JBL Pure Bass", "25"},
                {"Beats Studio Buds+", "890.00", "Écouteurs Beats Studio Buds+ avec ANC, audio spatial et compatibilité iOS/Android", "12"},
                {"Sennheiser Momentum 4 Wireless", "1190.00", "Casque Sennheiser Momentum 4 avec réduction de bruit adaptive et 60h d'autonomie", "6"},
                {"Anker Soundcore Q45", "490.00", "Casque Anker Soundcore Q45 avec réduction de bruit adaptive, 50h d'autonomie et Hi-Res", "30"},
                {"Marshall Major IV", "390.00", "Casque Marshall Major IV avec 80h d'autonomie, son signature Marshall et pliable", "15"},
                {"Logitech G733 Wireless Gaming", "490.00", "Casque gaming Logitech G733 sans fil avec LIGHTSPEED, RGB et DTS:X 7.1", "10"},
        };

        String[][] montres = {
                {"Apple Watch Ultra 2 49mm", "3290.00", "Montre connectée Apple Watch Ultra 2 avec écran 3000 nits, GPS double fréquence et autonomie 36h", "5"},
                {"Apple Watch Series 9 45mm", "2190.00", "Montre connectée Apple Watch Series 9 avec S9 SiP, écran Always-On et détection de chutes", "10"},
                {"Samsung Galaxy Watch6 Classic 47mm", "1590.00", "Montre connectée Samsung Galaxy Watch6 Classic avec lunette rotative, ECG et capteur BioActive", "8"},
                {"Huawei Watch GT 4 46mm", "890.00", "Montre connectée Huawei Watch GT 4 avec écran AMOLED 1.43\", GPS et 14 jours d'autonomie", "15"},
                {"Garmin Forerunner 265", "1390.00", "Montre GPS Garmin Forerunner 265 avec écran AMOLED, plans d'entraînement et métriques avancées", "7"},
                {"Fitbit Versa 4", "690.00", "Montre connectée Fitbit Versa 4 avec GPS intégré, suivi de santé et 6 jours d'autonomie", "12"},
                {"Amazfit T-Rex 2", "490.00", "Montre connectée Amazfit T-Rex 2 ultra-robuste avec GPS, 100+ modes sport et 24 jours d'autonomie", "20"},
                {"Xiaomi Watch S1 Pro", "690.00", "Montre connectée Xiaomi Watch S1 Pro avec écran AMOLED 1.47\", GPS et 14 jours d'autonomie", "18"},
                {"Fossil Gen 6 Wellness Edition", "990.00", "Montre connectée Fossil Gen 6 avec Wear OS, Snapdragon 4100+ et suivi SpO2", "6"},
                {"Withings ScanWatch Horizon", "1590.00", "Montre connectée Withings ScanWatch Horizon avec ECG, oxymètre et design classique suisse", "4"},
        };

        String[][] appareils = {
                {"Sony Alpha A7 IV 33MP", "7290.00", "Appareil photo Sony Alpha A7 IV hybride plein format 33MP avec vidéo 4K 60fps et stabilisation 5 axes", "3"},
                {"Canon EOS R6 Mark II", "7990.00", "Appareil photo Canon EOS R6 Mark II hybride 24.2MP avec vidéo 4K 60fps et double stabilisation", "2"},
                {"Nikon Z8", "8590.00", "Appareil photo Nikon Z8 hybride plein format 45.7MP avec vidéo 8K 60fps et EXPEED 7", "2"},
                {"Fujifilm X-T5 40MP", "5490.00", "Appareil photo Fujifilm X-T5 hybride APS-C 40.2MP avec simulations de films et IBIS", "4"},
                {"GoPro Hero 12 Black", "1590.00", "Caméra GoPro Hero 12 Black avec vidéo 5.3K 60fps, stabilisation HyperSmooth 6.0 et étanche 10m", "12"},
                {"Sony ZV-E1 Vlogging Camera", "4590.00", "Caméra Sony ZV-E1 plein format pour vlogging avec vidéo 4K 120fps, S-Cinetone et stabilisation active", "3"},
                {"Canon EOS 250D", "2490.00", "Appareil photo Canon EOS 250D reflex numérique 24.1MP avec écran tactile orientable et Wi-Fi", "7"},
                {"DJI Osmo Pocket 3", "1590.00", "Caméra DJI Osmo Pocket 3 avec capteur 1\", vidéo 4K 120fps et stabilisation à 3 axes", "10"},
                {"Insta360 X3", "1290.00", "Caméra Insta360 X3 à 360° avec vidéo 5.7K, stabilisation FlowState et étanche 10m", "8"},
                {"Panasonic Lumix GH6", "5990.00", "Appareil photo Panasonic Lumix GH6 Micro 4/3 avec vidéo 5.7K 60fps et stabilisation IBIS 7.5 stops", "3"},
        };

        String[][] gaming = {
                {"PlayStation 5 Slim 1TB", "2990.00", "Console PlayStation 5 Slim avec SSD 1TB, manette DualSense et support 4K 120Hz", "8"},
                {"Xbox Series X 1TB", "2890.00", "Console Xbox Series X avec SSD 1TB, 12 TFLOPS et compatibilité 4K 120Hz", "5"},
                {"Nintendo Switch OLED", "1490.00", "Console Nintendo Switch OLED avec écran 7\" OLED, 64GB et station d'accueil avec LAN", "12"},
                {"ASUS ROG Ally Z1 Extreme", "3290.00", "Console portable ASUS ROG Ally avec AMD Z1 Extreme, écran 7\" 1080p 120Hz et Windows 11", "4"},
                {"Steam Deck 512GB LCD", "2590.00", "Console portable Steam Deck avec APU AMD custom, écran 7\" 1280x800 60Hz et Linux SteamOS", "3"},
                {"Logitech G Pro X Superlight", "390.00", "Souris gaming Logitech G Pro X Superlight sans fil avec capteur HERO 25K et 63g", "20"},
                {"Razer BlackWidow V4 Pro", "590.00", "Clavier gaming Razer BlackWidow V4 Pro mécanique avec switches Green, RGB et repose-poignet", "10"},
                {"SteelSeries Arctis Nova Pro", "690.00", "Casque gaming SteelSeries Arctis Nova Pro avec ANC, Sonar audio et DAC GameDAC Gen 2", "8"},
                {"Samsung Odyssey G7 32\" 4K 144Hz", "2490.00", "Moniteur gaming Samsung Odyssey G7 32\" 4K UHD 144Hz, 1ms, HDR600 et G-Sync compatible", "5"},
                {"Thrustmaster T300 RS GT", "1990.00", "Volant gaming Thrustmaster T300 RS GT avec retour de force, compatible PS5/PS4/PC", "4"},
        };

        String[][] accessoires = {
                {"Apple AirTag Pack of 4", "290.00", "Tracker Apple AirTag pack de 4 avec puce U1 et réseau Localiser pour retrouver vos objets", "30"},
                {"Belkin BoostCharge Pro 3-en-1", "390.00", "Station de charge Belkin 3-en-1 avec MagSafe, charge rapide 15W pour iPhone, Watch et AirPods", "15"},
                {"Anker PowerCore 26800mAh", "190.00", "Batterie externe Anker PowerCore 26800mAh avec doubles ports USB-A et PowerIQ", "25"},
                {"Logitech MX Master 3S", "390.00", "Souris Logitech MX Master 3S sans fil avec capteur 8000 DPI, silencieuse et USB-C", "18"},
                {"Apple Magic Keyboard", "590.00", "Clavier Apple Magic Keyboard sans fil avec Touch ID, rétroéclairé et batterie rechargeable", "10"},
                {"Samsung T7 Portable SSD 1TB", "490.00", "SSD externe Samsung T7 1TB portable avec USB 3.2 Gen 2, 1050Mo/s et sécurité AES 256-bit", "12"},
                {"UGREEN USB-C Hub 9-en-1", "120.00", "Hub USB-C UGREEN 9-en-1 avec HDMI 4K, USB 3.0, SD/TF, PD 100W et Ethernet Gigabit", "40"},
                {"Spigen Ultra Hybrid iPhone Case", "59.00", "Coque Spigen Ultra Hybrid transparente pour iPhone avec protection anti-choc et antiraie", "50"},
                {"PopSockets PopGrip", "39.00", "PopSockets PopGrip interchangeable avec support adhésif et design personnalisable", "60"},
                {"Mous Limitless 5.0 Case", "129.00", "Coque Mous Limitless 5.0 avec protection antichoc AiroShock et compatibilité MagSafe", "20"},
        };

        String[][] enceintes = {
                {"Sonos Era 300", "1690.00", "Enceinte Sonos Era 300 avec audio spatial Dolby Atmos, Wi-Fi et AirPlay 2", "6"},
                {"JBL Charge 5", "590.00", "Enceinte portable JBL Charge 5 avec son JBL Original Pro, IP67 et 20h d'autonomie", "20"},
                {"Marshall Stanmore III", "1290.00", "Enceinte Marshall Stanmore III avec son stéréo, HDMI et design iconique", "8"},
                {"Bose SoundLink Revolve+ II", "890.00", "Enceinte portable Bose SoundLink Revolve+ II avec son 360°, IP55 et 17h d'autonomie", "10"},
                {"Sony SRS-XB43", "690.00", "Enceinte portable Sony SRS-XB43 avec EXTRA BASS, IP67 et 30h d'autonomie", "12"},
                {"Ultimate Ears Boom 3", "490.00", "Enceinte portable Ultimate Ears Boom 3 avec son 360°, IP67 et 15h d'autonomie", "18"},
                {"Harman Kardon Onyx Studio 8", "790.00", "Enceinte Harman Kardon Onyx Studio 8 avec son stéréo, design élégant et 8h d'autonomie", "7"},
                {"House of Marley Get Together 2", "690.00", "Enceinte House of Marley Get Together 2 avec son stéréo, Bluetooth 5.0 et matériaux recyclés", "5"},
                {"Anker Soundcore Motion+", "290.00", "Enceinte portable Anker Soundcore Motion+ avec son Hi-Res, 12h d'autonomie et IPX7", "30"},
                {"Bang & Olufsen Beosound A1 2nd Gen", "1290.00", "Enceinte portable Bang & Olufsen Beosound A1 avec son 360°, IP67 et Alexa intégré", "4"},
        };

        String[][] imprimantes = {
                {"HP LaserJet Pro M404dn", "1590.00", "Imprimante laser HP LaserJet Pro M404dn avec impression recto-verso, 38ppm et réseau Ethernet", "5"},
                {"Canon PIXMA G3460", "490.00", "Imprimante Canon PIXMA G3460 avec réservoir intégré, 6000 pages noir et 7700 couleur", "15"},
                {"Epson EcoTank L3250", "590.00", "Imprimante Epson EcoTank L3250 avec réservoir d'encre, Wi-Fi Direct et 4500 pages", "12"},
                {"Brother HL-L2350DW", "690.00", "Imprimante laser Brother HL-L2350DW avec recto-verso automatique, Wi-Fi et 30ppm", "8"},
                {"HP Envy 6455e", "390.00", "Imprimante HP Envy 6455e multifonction avec AirPrint, Wi-Fi et 3 mois d'encre Instant Ink", "20"},
                {"Canon imageCLASS MF445dw", "2290.00", "Imprimante Canon imageCLASS MF445dw laser multifonction avec recto-verso, Wi-Fi et 40ppm", "3"},
                {"Epson WorkForce WF-2860", "590.00", "Imprimante Epson WorkForce WF-2860 multifonction avec Wi-Fi Direct, AirPrint et ADF", "10"},
                {"Brother MFC-J995DW", "690.00", "Imprimante Brother MFC-J995DW multifonction avec INKvestment, AirPrint et écran tactile", "7"},
                {"HP Smart Tank 7001", "790.00", "Imprimante HP Smart Tank 7001 avec réservoir, Wi-Fi, Bluetooth et jusqu'à 6000 pages", "10"},
                {"Canon PIXMA TR8620a", "490.00", "Imprimante Canon PIXMA TR8620a multifonction avec ADF, AirPrint et fax", "8"},
        };

        String[][][] allProducts = {smartphones, laptops, tablettes, casques, montres, appareils, gaming, accessoires, enceintes, imprimantes};

        for (int catIdx = 0; catIdx < allProducts.length; catIdx++) {
            Category cat = categories.get(catIdx);
            for (String[] prod : allProducts[catIdx]) {
                String name = prod[0];
                BigDecimal price = new BigDecimal(prod[1]);
                String desc = prod[2];
                int stock = Integer.parseInt(prod[3]);
                boolean isFeatured = rnd.nextInt(10) < 2;

                Product product = productRepository.save(Product.builder()
                        .boutique(boutique)
                        .category(cat)
                        .name(name)
                        .description(desc)
                        .price(price)
                        .stock(stock)
                        .isActive(true)
                        .isFeatured(isFeatured)
                        .sku("SKU-" + BOUTIQUE_SLUG.toUpperCase() + "-" + name.toUpperCase().replaceAll("[^A-Z0-9]", "").substring(0, Math.min(10, name.replaceAll("[^A-Za-z0-9]", "").length())))
                        .build());
                products.add(product);
            }
        }

        return products;
    }

    private List<Customer> createCustomers(Boutique boutique) {
        String[] firstNames = {
                "Ahmed", "Mohamed", "Ali", "Salah", "Nour", "Imen", "Sarra", "Yassine", "Omar", "Hassen",
                "Fatma", "Amira", "Khaled", "Leila", "Mehdi", "Rania", "Sami", "Walid", "Salma", "Hichem",
                "Mariem", "Anis", "Donia", "Firas", "Asma", "Bilel", "Chaima", "Emna", "Montassar", "Sana",
                "Wassim", "Hela", "Mouna", "Kais", "Amal", "Moez", "Nadia", "Aymen", "Safa", "Youssef",
                "Rami", "Manel", "Selim", "Nawel", "Haythem", "Elhem", "Rabii", "Ines", "Dhia", "Noura"
        };
        String[] lastNames = {
                "Ben Ali", "Trabelsi", "Khammassi", "Mabrouk", "Hadj Ahmed", "Slimane", "Mejri", "Jaziri",
                "Bouazizi", "Mansouri", "Gharbi", "Dridi", "Ayari", "Laabidi", "Zribi", "Khemiri",
                "Cherni", "Ben Salah", "Chaari", "Ben Amor", "Hammami", "Chouchen", "Karray", "Boussetta",
                "Moussa", "Ben Youssef", "Zouari", "Hajji", "Dhaouadi", "Ben Hassen", "Naceur",
                "Bouguerra", "Sghaier", "Maalej", "Ben Romdhane", "Louati", "Sassi", "Guesmi"
        };
        String[] cities = {
                "Tunis", "Sfax", "Sousse", "Nabeul", "Gabès", "Bizerte", "Monastir", "Kairouan",
                "Ariana", "Ben Arous", "Mannouba", "Hammamet", "Zarzis", "Gafsa", "Tozeur", "Mahdia",
                "Jendouba", "Béja", "El Kef", "Médenine", "Tataouine", "Kasserine", "Siliana", "Zaghouan"
        };
        String[] phones = {
                "50", "55", "52", "23", "22", "27", "20", "54", "58", "59", "21", "24", "25", "26", "28"
        };

        List<Customer> customers = new ArrayList<>();
        Set<String> usedEmails = new HashSet<>();

        Random rnd = ThreadLocalRandom.current();

        for (int i = 0; i < 50; i++) {
            String firstName = firstNames[rnd.nextInt(firstNames.length)];
            String lastName = lastNames[rnd.nextInt(lastNames.length)];
            String fullName = firstName + " " + lastName;
            String email = (firstName + "." + lastName + "@gmail.com").toLowerCase().replaceAll("\\s+", ".");
            while (usedEmails.contains(email)) {
                email = (firstName + "." + lastName + rnd.nextInt(10000) + "@gmail.com").toLowerCase().replaceAll("\\s+", ".");
            }
            usedEmails.add(email);
            String phone = "+216 " + phones[rnd.nextInt(phones.length)] + String.format("%06d", rnd.nextInt(1_000_000));
            String city = cities[rnd.nextInt(cities.length)];
            String[] governorates = {"Tunis", "Ariana", "Ben Arous", "Mannouba", "Sfax", "Sousse", "Nabeul", "Bizerte", "Gabès", "Monastir", "Kairouan", "Gafsa", "Mahdia", "Médenine", "Zaghouan"};
            String governorate = governorates[rnd.nextInt(governorates.length)];
            String address = rnd.nextBoolean()
                    ? "Avenue " + (rnd.nextBoolean() ? "Habib Bourguiba" : "Mohamed V") + ", N°" + (rnd.nextInt(200) + 1)
                    : "Rue " + (rnd.nextBoolean() ? "Ibn Khaldoun" : "Ali Belhouane") + ", N°" + (rnd.nextInt(150) + 1);

            Customer customer = customerRepository.save(Customer.builder()
                    .boutique(boutique)
                    .fullName(fullName)
                    .email(email)
                    .phone(phone)
                    .address(address)
                    .city(city)
                    .governorate(governorate)
                    .country("Tunisie")
                    .build());
            customers.add(customer);
        }

        return customers;
    }

    private void createOrders(Boutique boutique, List<Product> products, List<Customer> customers) {
        Random rnd = ThreadLocalRandom.current();
        String[] statuses = {"PENDING", "CONFIRMED", "PROCESSING", "SHIPPED", "DELIVERED", "CANCELLED"};
        int[] statusWeights = {50, 30, 30, 20, 50, 20};
        int totalWeight = 0;
        for (int w : statusWeights) totalWeight += w;

        String[] paymentMethods = {"COD", "CARTE_BANCAIRE", "CARTE_BANCAIRE", "D17", "EDINAR"};
        String[] cities = {
                "Tunis", "Sfax", "Sousse", "Nabeul", "Gabès", "Bizerte", "Monastir", "Kairouan",
                "Ariana", "Ben Arous", "Hammamet", "Mahdia", "Gafsa", "Tozeur", "Médenine"
        };

        LocalDateTime baseDate = LocalDateTime.of(2026, 1, 1, 0, 0);
        int orderSeq = 1;

        for (int i = 0; i < 200; i++) {
            String status = selectWeighted(statuses, statusWeights, totalWeight, rnd);
            Customer customer = customers.get(rnd.nextInt(customers.size()));

            int itemCount = rnd.nextInt(4) + 1;
            List<Product> orderProducts = new ArrayList<>();
            for (int j = 0; j < itemCount; j++) {
                orderProducts.add(products.get(rnd.nextInt(products.size())));
            }

            BigDecimal subtotal = BigDecimal.ZERO;
            List<OrderItem> items = new ArrayList<>();
            for (Product p : orderProducts) {
                int qty = rnd.nextInt(3) + 1;
                BigDecimal lineSubtotal = p.getPrice().multiply(BigDecimal.valueOf(qty));
                subtotal = subtotal.add(lineSubtotal);

                OrderItem item = OrderItem.builder()
                        .product(p)
                        .productName(p.getName())
                        .unitPrice(p.getPrice())
                        .quantity(qty)
                        .subtotal(lineSubtotal)
                        .build();
                items.add(item);
            }

            BigDecimal shipping = rnd.nextDouble() < 0.2 ? BigDecimal.ZERO : BigDecimal.valueOf(7);
            BigDecimal total = subtotal.add(shipping);

            String paymentMethod = paymentMethods[rnd.nextInt(paymentMethods.length)];
            String paymentStatus;
            if ("DELIVERED".equals(status)) {
                paymentStatus = "PAID";
            } else if ("CANCELLED".equals(status)) {
                paymentStatus = "REFUNDED";
            } else if ("PENDING".equals(status)) {
                paymentStatus = "UNPAID";
            } else {
                paymentStatus = rnd.nextBoolean() ? "PAID" : "UNPAID";
            }

            LocalDateTime orderDate = baseDate.plusHours(rnd.nextInt(24 * 180));
            String orderNumber = "SEED-" + String.format("%04d", orderSeq++);

            String city = cities[rnd.nextInt(cities.length)];
            String shippingAddress = rnd.nextBoolean()
                    ? "Avenue " + (rnd.nextBoolean() ? "Habib Bourguiba" : "de la Liberté") + ", N°" + (rnd.nextInt(200) + 1)
                    : "Rue " + (rnd.nextBoolean() ? "Ibn Rochd" : "des Entrepreneurs") + ", N°" + (rnd.nextInt(150) + 1);

            Order order = Order.builder()
                    .boutique(boutique)
                    .customer(customer)
                    .orderNumber(orderNumber)
                    .status(status)
                    .subtotal(subtotal)
                    .shippingFee(shipping)
                    .discount(BigDecimal.ZERO)
                    .total(total)
                    .paymentMethod(paymentMethod)
                    .paymentStatus(paymentStatus)
                    .customerName(customer.getFullName())
                    .customerEmail(customer.getEmail())
                    .customerPhone(customer.getPhone())
                    .city(city)
                    .shippingAddress(shippingAddress)
                    .notes(rnd.nextDouble() < 0.3 ? "Merci de livrer avant 18h" : null)
                    .build();

            for (OrderItem item : items) {
                order.getItems().add(item);
                item.setOrder(order);
            }

            orderRepository.save(order);
        }

        updateCustomerStats(boutique);
    }

    private void updateCustomerStats(Boutique boutique) {
        List<Customer> customers = customerRepository.findByBoutiqueId(boutique.getId(),
                org.springframework.data.domain.Pageable.unpaged()).getContent();
        for (Customer c : customers) {
            long orderCount = customerRepository.countByCustomerId(c.getId());
            Double totalSpent = customerRepository.sumTotalByCustomerId(c.getId());
            LocalDateTime lastOrder = customerRepository.findLastOrderDateByCustomerId(c.getId());
            c.setTotalOrders((int) orderCount);
            c.setTotalSpent(totalSpent != null ? BigDecimal.valueOf(totalSpent) : BigDecimal.ZERO);
            c.setLastOrderDate(lastOrder);
            customerRepository.save(c);
        }
    }

    private String selectWeighted(String[] items, int[] weights, int totalWeight, Random rnd) {
        int r = rnd.nextInt(totalWeight);
        int cumulative = 0;
        for (int i = 0; i < items.length; i++) {
            cumulative += weights[i];
            if (r < cumulative) return items[i];
        }
        return items[items.length - 1];
    }
}
