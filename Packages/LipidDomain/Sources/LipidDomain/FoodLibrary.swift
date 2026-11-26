// 食物库：106 条，全部为估算值，未对照《中国食物成分表》核实。
// 数据与 web-prototype/shared/foods.js 一致。
import Foundation

public enum FoodLibrary {
    public static let dataSource = "估算值（未核实）"
    public static let dataVersion = "demo-0.2"

    public static let categories: [FoodCategory] = [
        FoodCategory(id: "fatty_processed_meat", name: "肥肉与加工肉", short: "肥肉", emoji: "🥓", swap: "steamed_fish"),
        FoodCategory(id: "fried", name: "油炸食品", short: "油炸", emoji: "🍟", swap: "steamed_fish"),
        FoodCategory(id: "milk_tea", name: "奶茶与含植脂末饮品", short: "奶茶", emoji: "🧋", swap: "tea"),
        FoodCategory(id: "offal", name: "动物内脏", short: "内脏", emoji: "🫀", swap: "tofu"),
        FoodCategory(id: "lean_meat", name: "畜肉", short: "畜肉", emoji: "🥩", swap: "chicken_breast"),
        FoodCategory(id: "poultry", name: "禽肉", short: "禽肉", emoji: "🍗", swap: "chicken_breast"),
        FoodCategory(id: "fish_seafood", name: "鱼虾水产", short: "水产", emoji: "🐟", swap: "steamed_fish"),
        FoodCategory(id: "egg", name: "蛋类", short: "蛋", emoji: "🥚", swap: nil),
        FoodCategory(id: "dairy", name: "奶类", short: "奶", emoji: "🥛", swap: "skim_milk"),
        FoodCategory(id: "soy", name: "豆制品", short: "豆", emoji: "🫘", swap: nil),
        FoodCategory(id: "dish", name: "家常菜", short: "家常菜", emoji: "🥘", swap: nil),
        FoodCategory(id: "vegetable", name: "蔬菜", short: "蔬菜", emoji: "🥬", swap: nil),
        FoodCategory(id: "staple", name: "主食", short: "主食", emoji: "🍚", swap: nil),
        FoodCategory(id: "whole_grain", name: "全谷与薯类", short: "全谷", emoji: "🌾", swap: nil),
        FoodCategory(id: "fruit", name: "水果", short: "水果", emoji: "🍎", swap: nil),
        FoodCategory(id: "nuts", name: "坚果", short: "坚果", emoji: "🥜", swap: nil),
        FoodCategory(id: "pastry", name: "糕点甜食", short: "甜食", emoji: "🍰", swap: "apple"),
        FoodCategory(id: "dining_out", name: "外食与聚餐", short: "外食", emoji: "🍲", swap: nil),
        FoodCategory(id: "drink", name: "饮品", short: "饮品", emoji: "🍵", swap: nil),
    ]

    public static let categoryById: [String: FoodCategory] = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

    /// 饱和脂肪 g、反式脂肪 g、胆固醇 mg、可溶性纤维 g，均为每 100 g 可食部。
    private static func f(_ id: String, _ name: String, _ emoji: String, _ category: String,
                          _ sat: Double, _ trans: Double, _ chol: Double, _ fiber: Double,
                          _ servings: [(String, Double)], _ defaultServing: Int = 0, _ aliases: [String] = [], _ swap: Swap = .inherit) -> Food {
        Food(id: id, name: name, emoji: emoji, category: category, aliases: aliases,
             nutritionPer100g: Nutrition(satFatG: sat, transFatG: trans, cholesterolMg: chol, solubleFiberG: fiber),
             servings: servings.map { Serving(label: $0.0, grams: $0.1) }, defaultServing: defaultServing, swap: swap,
             source: dataSource, dataVersion: dataVersion)
    }

    public static let foods: [Food] = [
        f("braised_pork", "红烧肉", "🍖", "fatty_processed_meat", 12.4, 0, 86, 0, [("一小块", 30), ("小碗", 60), ("中碗", 100), ("大碗", 150)], 2, ["东坡肉", "扣肉"]),
        f("pork_belly", "五花肉", "🥩", "fatty_processed_meat", 11, 0, 80, 0, [("小碗", 60), ("中碗", 100), ("半盘", 150)], 1, ["回锅肉", "烤五花"]),
        f("chinese_sausage", "腊肠", "🌭", "fatty_processed_meat", 17, 0, 90, 0, [("片", 10), ("半根", 25), ("一根", 50)], 1, ["香肠", "腊肉"]),
        f("bacon", "培根", "🥓", "fatty_processed_meat", 14, 0, 70, 0, [("片", 15)], 0, ["烟肉"]),
        f("luncheon_meat", "午餐肉", "🥫", "fatty_processed_meat", 9, 0, 60, 0, [("片", 30)], 0, []),
        f("spare_ribs", "红烧排骨", "🍖", "fatty_processed_meat", 8, 0, 85, 0, [("一块", 30), ("小碗", 90), ("中碗", 150)], 1, ["排骨", "糖醋排骨"]),
        f("ham_sausage", "火腿肠", "🌭", "fatty_processed_meat", 6, 0, 50, 0, [("根", 40)], 0, []),

        f("fried_chicken", "炸鸡", "🍗", "fried", 5.5, 0.2, 90, 0, [("一块", 80), ("小份", 150), ("大份", 250)], 0, ["炸鸡块", "炸鸡腿"], .food("chicken_breast")),
        f("youtiao", "油条", "🥖", "fried", 3.5, 0.3, 0, 0.3, [("半根", 30), ("根", 60)], 1, [], .food("mantou")),
        f("french_fries", "薯条", "🍟", "fried", 3.5, 0.4, 0, 0.8, [("小份", 70), ("中份", 110), ("大份", 150)], 1, [], .food("sweet_potato")),
        f("spring_roll", "炸春卷", "🥠", "fried", 4, 0.2, 15, 0.5, [("个", 40)], 0, ["春卷"], .food("mantou")),
        f("fried_fish", "炸鱼排", "🐟", "fried", 4, 0.2, 60, 0, [("块", 90)], 0, ["炸鱼"], .food("steamed_fish")),

        f("bubble_tea", "珍珠奶茶", "🧋", "milk_tea", 2.2, 0.15, 3, 0, [("半杯", 250), ("中杯", 500), ("大杯", 700)], 1, ["奶茶", "波霸奶茶"]),
        f("instant_coffee", "三合一速溶咖啡", "☕", "milk_tea", 9, 0.5, 0, 0, [("条", 15)], 0, ["速溶咖啡"], .food("americano")),
        f("cheese_foam_tea", "奶盖茶", "🥤", "milk_tea", 2.8, 0.15, 10, 0, [("中杯", 500)], 0, []),

        f("pork_liver", "猪肝", "🫀", "offal", 1.5, 0, 290, 0, [("小碗", 50), ("中碗", 100)], 0, ["炒猪肝"]),
        f("pork_intestine", "肥肠", "🫀", "offal", 7, 0, 140, 0, [("小碗", 60), ("中碗", 100)], 0, ["猪大肠"]),
        f("tripe", "毛肚", "🫀", "offal", 0.5, 0, 100, 0, [("小碗", 60), ("中碗", 100)], 0, ["牛百叶"]),

        f("lean_pork", "瘦猪肉", "🥩", "lean_meat", 2.2, 0, 80, 0, [("小碗", 50), ("手掌大小", 80), ("中碗", 100)], 1, ["里脊", "肉丝"]),
        f("lean_beef", "瘦牛肉", "🥩", "lean_meat", 1.9, 0, 60, 0, [("小碗", 60), ("手掌大小", 80), ("中碗", 100)], 1, ["卤牛肉", "牛腱"]),
        f("steak", "牛排", "🥩", "lean_meat", 6, 0, 70, 0, [("手掌大小", 120), ("一块", 200)], 0, ["肥牛"]),
        f("lamb", "羊肉", "🍖", "lean_meat", 5.5, 0, 80, 0, [("串", 25), ("小碗", 60), ("中碗", 100)], 1, ["涮羊肉", "羊肉串"]),
        f("minced_pork", "猪肉馅", "🥩", "lean_meat", 6, 0, 75, 0, [("小碗", 50), ("中碗", 100)], 0, ["肉末", "肉丸"]),

        f("chicken_breast", "鸡胸肉", "🍗", "poultry", 0.6, 0, 65, 0, [("半块", 60), ("手掌大小", 100)], 1, ["水煮鸡胸"]),
        f("chicken_leg", "去皮鸡腿", "🍗", "poultry", 1.6, 0, 90, 0, [("个", 100)], 0, ["鸡腿"]),
        f("chicken_skin_on", "白切鸡", "🐔", "poultry", 3.5, 0, 95, 0, [("小碗", 80), ("中碗", 130)], 0, ["带皮鸡肉", "盐焗鸡"]),
        f("roast_duck", "烤鸭", "🦆", "poultry", 9, 0, 90, 0, [("小碗", 60), ("中碗", 100), ("半盘", 150)], 1, ["烧鸭"]),
        f("chicken_wing", "鸡翅", "🍗", "poultry", 3.8, 0, 110, 0, [("个", 35)], 0, ["烤翅"]),

        f("steamed_fish", "清蒸鱼", "🐟", "fish_seafood", 0.9, 0, 70, 0, [("小碗", 70), ("手掌大小", 100), ("半条", 150)], 1, ["蒸鲈鱼", "蒸鱼"], .none),
        f("salmon", "三文鱼", "🍣", "fish_seafood", 2.5, 0, 55, 0, [("片", 15), ("手掌大小", 100)], 1, []),
        f("pan_fried_fish", "香煎带鱼", "🐟", "fish_seafood", 2.8, 0, 75, 0, [("段", 40), ("小碗", 100)], 0, ["带鱼", "煎鱼"]),
        f("shrimp", "白灼虾", "🦐", "fish_seafood", 0.3, 0, 150, 0, [("只", 10), ("小碗", 60), ("中碗", 100)], 1, ["虾", "基围虾"], .none),
        f("squid", "鱿鱼", "🦑", "fish_seafood", 0.4, 0, 230, 0, [("小碗", 60), ("中碗", 100)], 0, ["烤鱿鱼"], .none),

        f("boiled_egg", "水煮蛋", "🥚", "egg", 3.1, 0, 370, 0, [("个", 50)], 0, ["鸡蛋", "白煮蛋", "茶叶蛋"]),
        f("fried_egg", "煎蛋", "🍳", "egg", 4.5, 0, 400, 0, [("个", 55)], 0, ["荷包蛋"]),
        f("salted_duck_egg", "咸鸭蛋", "🥚", "egg", 3.8, 0, 650, 0, [("半个", 30), ("个", 60)], 0, []),
        f("egg_white", "蛋白", "🥚", "egg", 0, 0, 0, 0, [("个", 33)], 0, ["蛋清"]),

        f("whole_milk", "全脂牛奶", "🥛", "dairy", 1.9, 0, 12, 0, [("盒", 200), ("杯", 250)], 1, ["牛奶"]),
        f("skim_milk", "脱脂牛奶", "🥛", "dairy", 0.1, 0, 3, 0, [("盒", 200), ("杯", 250)], 1, [], .none),
        f("yogurt", "酸奶", "🥛", "dairy", 1.7, 0, 10, 0, [("小盒", 100), ("杯", 150)], 0, []),
        f("cheese", "奶酪", "🧀", "dairy", 18, 0, 90, 0, [("片", 20)], 0, ["芝士"]),
        f("ice_cream", "冰淇淋", "🍦", "dairy", 7, 0, 40, 0, [("球", 60)], 0, ["雪糕"]),

        f("tofu", "豆腐", "🫘", "soy", 0.7, 0, 0, 0.2, [("块", 80), ("小碗", 100), ("中碗", 150)], 1, ["北豆腐", "炖豆腐"]),
        f("soy_milk", "豆浆", "🥤", "soy", 0.25, 0, 0, 0.3, [("杯", 300)], 0, []),
        f("dried_tofu", "豆腐干", "🫘", "soy", 2, 0, 0, 0.4, [("片", 20), ("小碗", 50)], 1, ["香干"]),
        f("edamame", "毛豆", "🫛", "soy", 0.6, 0, 0, 1.5, [("小碗", 60)], 0, []),
        f("red_beans", "红豆", "🫘", "soy", 0.1, 0, 0, 1.5, [("小碗", 80), ("中碗", 150)], 0, ["杂豆", "煮豆", "红豆汤"]),

        f("tomato_egg", "番茄炒蛋", "🍅", "dish", 1.5, 0, 150, 0.2, [("小碗", 100), ("中碗", 180)], 0, ["西红柿炒鸡蛋"]),
        f("kung_pao_chicken", "宫保鸡丁", "🥘", "dish", 2.2, 0, 55, 0.3, [("小碗", 100), ("中碗", 160)], 0, []),
        f("yuxiang_pork", "鱼香肉丝", "🥘", "dish", 2.8, 0, 45, 0.3, [("小碗", 100), ("中碗", 160)], 0, []),
        f("mapo_tofu", "麻婆豆腐", "🌶️", "dish", 1.9, 0, 10, 0.2, [("小碗", 100), ("中碗", 150)], 1, []),
        f("pepper_pork", "青椒肉丝", "🫑", "dish", 1.9, 0, 40, 0.3, [("小碗", 100), ("中碗", 160)], 0, []),
        f("sour_fish", "酸菜鱼", "🐟", "dish", 1.8, 0, 60, 0.1, [("小碗", 150), ("中碗", 250)], 0, []),
        f("seaweed_egg_soup", "紫菜蛋花汤", "🍲", "dish", 0.4, 0, 60, 0.2, [("碗", 250)], 0, []),
        f("rib_soup", "排骨汤", "🍲", "dish", 1.5, 0, 15, 0, [("碗", 250)], 0, ["骨头汤"]),

        f("stir_fried_greens", "炒青菜", "🥬", "vegetable", 0.6, 0, 0, 0.5, [("小碗", 100), ("中碗", 150), ("半盘", 200)], 0, ["小白菜", "油麦菜", "菠菜"]),
        f("broccoli", "西兰花", "🥦", "vegetable", 0.3, 0, 0, 0.9, [("小碗", 100), ("中碗", 150)], 0, []),
        f("cucumber_salad", "凉拌黄瓜", "🥒", "vegetable", 0.1, 0, 0, 0.2, [("小碗", 100)], 0, ["拍黄瓜"]),
        f("braised_eggplant", "红烧茄子", "🍆", "vegetable", 1.2, 0, 0, 1, [("小碗", 100), ("中碗", 150)], 0, ["茄子"]),
        f("shredded_potato", "土豆丝", "🥔", "vegetable", 0.8, 0, 0, 0.4, [("小碗", 100), ("中碗", 150)], 0, []),
        f("mushroom", "炒蘑菇", "🍄", "vegetable", 0.4, 0, 0, 0.5, [("小碗", 100)], 0, ["香菇", "木耳"]),
        f("carrot", "胡萝卜", "🥕", "vegetable", 0.1, 0, 0, 1, [("根", 100)], 0, []),

        f("rice", "米饭", "🍚", "staple", 0.1, 0, 0, 0, [("小碗", 100), ("中碗", 150), ("大碗", 250)], 1, ["白饭"]),
        f("mantou", "馒头", "🫓", "staple", 0.2, 0, 0, 0.3, [("个", 80)], 0, ["花卷"]),
        f("noodles", "汤面", "🍜", "staple", 0.2, 0, 0, 0.3, [("小碗", 150), ("中碗", 250), ("大碗", 350)], 1, ["面条", "挂面"]),
        f("congee", "白粥", "🥣", "staple", 0, 0, 0, 0, [("中碗", 250)], 0, ["稀饭"]),
        f("pork_bun", "肉包", "🥟", "staple", 2.5, 0, 20, 0.3, [("个", 90)], 0, ["包子", "小笼包"]),
        f("dumplings", "猪肉水饺", "🥟", "staple", 2.2, 0, 25, 0.4, [("个", 20), ("小盘", 160), ("一盘", 300)], 1, ["饺子", "馄饨"]),
        f("fried_rice", "蛋炒饭", "🍛", "staple", 1.5, 0, 60, 0.1, [("小碗", 150), ("中碗", 250), ("一盘", 350)], 1, ["炒饭"], .food("rice")),
        f("instant_noodles", "方便面", "🍜", "staple", 7.5, 0, 0, 0.8, [("包", 100)], 0, ["泡面"], .food("noodles")),
        f("white_bread", "白面包", "🍞", "staple", 0.8, 0, 0, 0.5, [("片", 35)], 0, ["吐司"]),
        f("jianbing", "煎饼果子", "🌯", "staple", 1.8, 0.1, 90, 0.5, [("个", 250)], 0, []),

        f("oat_porridge", "燕麦粥", "🥣", "whole_grain", 0.3, 0, 0, 0.7, [("小碗", 150), ("中碗", 250), ("大碗", 350)], 1, ["麦片粥"]),
        f("oats", "燕麦片", "🌾", "whole_grain", 1.2, 0, 0, 4, [("勺", 15), ("一份", 40)], 1, ["干燕麦"]),
        f("brown_rice", "杂粮饭", "🍚", "whole_grain", 0.2, 0, 0, 0.3, [("小碗", 100), ("中碗", 150)], 1, ["糙米饭"]),
        f("corn", "玉米", "🌽", "whole_grain", 0.2, 0, 0, 0.5, [("半根", 75), ("根", 150)], 1, []),
        f("sweet_potato", "红薯", "🍠", "whole_grain", 0.05, 0, 0, 1, [("半个", 100), ("个", 200)], 0, ["烤红薯", "地瓜"]),
        f("whole_wheat_bread", "全麦面包", "🍞", "whole_grain", 0.5, 0, 0, 1, [("片", 35)], 0, []),

        f("apple", "苹果", "🍎", "fruit", 0, 0, 0, 0.9, [("半个", 90), ("个", 180)], 1, []),
        f("orange", "橙子", "🍊", "fruit", 0, 0, 0, 1.1, [("个", 150)], 0, ["橘子"]),
        f("banana", "香蕉", "🍌", "fruit", 0.1, 0, 0, 0.6, [("根", 100)], 0, []),
        f("pear", "梨", "🍐", "fruit", 0, 0, 0, 0.8, [("个", 200)], 0, []),
        f("kiwi", "猕猴桃", "🥝", "fruit", 0, 0, 0, 0.8, [("个", 80)], 0, []),
        f("grapes", "葡萄", "🍇", "fruit", 0, 0, 0, 0.2, [("小碗", 100)], 0, []),
        f("watermelon", "西瓜", "🍉", "fruit", 0, 0, 0, 0.1, [("块", 200)], 0, []),

        f("walnut", "核桃", "🌰", "nuts", 6, 0, 0, 1.5, [("个", 8), ("一小把", 25)], 1, []),
        f("peanut", "花生", "🥜", "nuts", 7, 0, 0, 1, [("一小把", 20)], 0, []),
        f("almond", "巴旦木", "🥜", "nuts", 3.8, 0, 0, 1, [("一小把", 20)], 0, ["杏仁"]),

        f("cream_cake", "奶油蛋糕", "🍰", "pastry", 9, 0.3, 80, 0.2, [("块", 80)], 0, ["蛋糕"]),
        f("biscuit", "饼干", "🍪", "pastry", 9, 0.3, 20, 0.5, [("片", 8), ("小包", 40)], 1, ["曲奇"]),
        f("egg_tart", "蛋挞", "🥧", "pastry", 8, 0.3, 120, 0, [("个", 55)], 0, []),
        f("croissant", "牛角包", "🥐", "pastry", 11, 0.4, 60, 0.5, [("个", 60)], 0, ["可颂"], .food("whole_wheat_bread")),
        f("mooncake", "月饼", "🥮", "pastry", 7, 0.2, 60, 0.3, [("四分之一", 25), ("个", 100)], 0, []),
        f("chocolate", "巧克力", "🍫", "pastry", 19, 0, 10, 1, [("一小块", 10)], 0, []),

        f("hotpot_tallow", "牛油火锅", "🍲", "dining_out", 3.6, 0, 55, 0.3, [("少量", 300), ("正常", 500), ("吃撑", 750)], 1, ["火锅", "麻辣火锅"], .food("hotpot_clear")),
        f("hotpot_clear", "清汤火锅", "🍲", "dining_out", 1.6, 0, 50, 0.4, [("少量", 300), ("正常", 500), ("吃撑", 750)], 1, ["菌汤火锅", "涮锅"]),
        f("bbq", "烧烤", "🍢", "dining_out", 5, 0, 75, 0, [("少量", 150), ("正常", 300), ("吃撑", 450)], 1, ["撸串", "烤肉"]),
        f("burger", "汉堡", "🍔", "dining_out", 4.5, 0.2, 35, 0.4, [("个", 220)], 0, []),
        f("pizza", "披萨", "🍕", "dining_out", 4.5, 0.2, 20, 0.5, [("片", 100)], 0, []),
        f("rice_bowl", "外卖盖饭", "🍱", "dining_out", 1.6, 0, 25, 0.3, [("半份", 250), ("一份", 500)], 1, ["盖浇饭", "便当"]),
        f("malatang", "麻辣烫", "🥘", "dining_out", 1.5, 0, 30, 0.4, [("小份", 400), ("大份", 600)], 0, []),
        f("beef_noodle", "牛肉面", "🍜", "dining_out", 0.8, 0, 8, 0.2, [("碗", 600)], 0, ["兰州拉面"]),
        f("banquet", "中式宴席", "🥂", "dining_out", 2.8, 0, 60, 0.3, [("少量", 400), ("正常", 600), ("吃撑", 900)], 1, ["聚餐", "酒席"]),

        f("tea", "无糖茶", "🍵", "drink", 0, 0, 0, 0, [("杯", 300)], 0, ["绿茶", "乌龙茶"]),
        f("americano", "美式咖啡", "☕", "drink", 0, 0, 0, 0, [("杯", 350)], 0, ["黑咖啡"]),
        f("latte", "拿铁", "☕", "drink", 1.1, 0, 6, 0, [("中杯", 350)], 0, []),
    ]

    /// 食物表。`overrides` 是份量校准：食物 id → 量具 → 克数。
    public static func foodMap(overrides: [String: [String: Double]] = [:]) -> [String: Food] {
        var m: [String: Food] = [:]
        for var food in foods {
            if let o = overrides[food.id] {
                food.servings = food.servings.map { s in
                    if let g = o[s.label], g > 0 { return Serving(label: s.label, grams: g) }
                    return s
                }
            }
            m[food.id] = food
        }
        return m
    }

    /// 纤维补充候选（P3 建议用）。
    public static let fiberBoosters: [Advisor.Booster] = [
        .init(foodId: "oat_porridge", servingLabel: "中碗"),
        .init(foodId: "red_beans", servingLabel: "小碗"),
        .init(foodId: "apple", servingLabel: "个"),
    ]

    /// 默认限额为产品建议值，不是指南原文。
    public static let defaultLimits: [CountLimit] = [
        CountLimit(id: "limit_01", category: "fatty_processed_meat", maxCount: 2),
        CountLimit(id: "limit_02", category: "fried", maxCount: 1),
        CountLimit(id: "limit_03", category: "milk_tea", maxCount: 1),
        CountLimit(id: "limit_04", category: "offal", maxCount: 1),
    ]
}
