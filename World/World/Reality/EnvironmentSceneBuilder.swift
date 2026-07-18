//
//  EnvironmentSceneBuilder.swift
//  World
//

import RealityKit
import AppKit
import ImageIO
import simd

/// Assembles the stocked-lake environment from the individually-authored USDZ assets
/// shipped by the asset repo. The core assets (dock, water, terrain, sky, horizon ring)
/// were authored together in one shared coordinate frame, so they compose correctly as
/// siblings at identity transform — verified directly against the asset repo's own
/// `preview_scene.blend` (see `scatterInstances` below): `dock_main`, `water_surface`,
/// `terrain_underwater`, `terrain_horizon_ring`, and `sky_dome` all sit at world-origin
/// identity there too, confirming this isn't just an assumption.
@MainActor
enum EnvironmentSceneBuilder {

    /// Sun convention from the asset repo's lighting spec: golden hour, ~15° elevation,
    /// 135° azimuth (behind-left of the player), warm ~3200-4000K.
    private static let sunElevationDegrees: Float = 15
    private static let sunAzimuthDegrees: Float = 135
    private static let sunColor = NSColor(srgbRed: 1.0, green: 0.82, blue: 0.62, alpha: 1.0)
    private static let sunDistance: Float = 200

    private static let coreAssetNames = [
        "water_surface",
        "terrain_underwater",
        "terrain_horizon_ring",
        "dock_main",
        "sky_dome"
    ]

    private struct ScatterInstance {
        let assetName: String
        let position: SIMD3<Float>
        let scale: Float
    }

    /// Exact authored layout, extracted from the asset repo's `preview_scene.blend`
    /// (`FishAssets/Environment/Model/preview_scene/preview_scene.blend`) — every scattered
    /// tree/rock/foliage instance's real position and uniform scale, converted from Blender's
    /// Z-up space via the verified `(x, y, z) -> (x, z, -y)` mapping (cross-checked against
    /// `dock_main.usdz`'s known bounding box before trusting it across all ~200 instances).
    /// Every instance's authored rotation is identity (matrix_world, not the stale/unused
    /// `rotation_euler` field also present on these objects) — no yaw variation to carry over.
    /// Replaces the previous seeded-random placeholder scatter.
    private static let scatterInstances: [ScatterInstance] = [
        // foliage_grass_01 (70 instances)
        ScatterInstance(assetName: "foliage_grass_01", position: [-33.5293, 0.5663, 18.4041], scale: 1.4613),
        ScatterInstance(assetName: "foliage_grass_01", position: [-45.9508, 1.6892, -7.5450], scale: 1.2910),
        ScatterInstance(assetName: "foliage_grass_01", position: [-35.9707, 3.4472, 47.6765], scale: 0.9992),
        ScatterInstance(assetName: "foliage_grass_01", position: [-35.2181, 1.5234, -30.7390], scale: 1.1232),
        ScatterInstance(assetName: "foliage_grass_01", position: [12.1559, 0.0000, -21.4832], scale: 1.3378),
        ScatterInstance(assetName: "foliage_grass_01", position: [20.5613, -0.1186, -21.7145], scale: 1.4100),
        ScatterInstance(assetName: "foliage_grass_01", position: [33.2041, 0.9048, -18.4124], scale: 1.4184),
        ScatterInstance(assetName: "foliage_grass_01", position: [23.0066, 4.2868, 49.4714], scale: 1.0907),
        ScatterInstance(assetName: "foliage_grass_01", position: [-34.9623, 2.2117, -42.9328], scale: 0.9056),
        ScatterInstance(assetName: "foliage_grass_01", position: [13.0921, 0.1304, -26.1881], scale: 1.1395),
        ScatterInstance(assetName: "foliage_grass_01", position: [-25.8500, 0.0816, 16.2059], scale: 1.0933),
        ScatterInstance(assetName: "foliage_grass_01", position: [-29.0523, 0.7079, -31.2298], scale: 1.2833),
        ScatterInstance(assetName: "foliage_grass_01", position: [-44.4921, 0.1366, 4.3444], scale: 0.8378),
        ScatterInstance(assetName: "foliage_grass_01", position: [41.3322, 1.8137, 30.2153], scale: 1.3585),
        ScatterInstance(assetName: "foliage_grass_01", position: [-28.0465, 0.8141, -22.5045], scale: 1.2440),
        ScatterInstance(assetName: "foliage_grass_01", position: [20.9802, 0.0000, -8.6513], scale: 0.9136),
        ScatterInstance(assetName: "foliage_grass_01", position: [-11.8497, 0.0000, -18.6582], scale: 0.9059),
        ScatterInstance(assetName: "foliage_grass_01", position: [27.7590, 0.2714, -20.5610], scale: 1.4120),
        ScatterInstance(assetName: "foliage_grass_01", position: [-19.5594, 0.0000, 17.0416], scale: 1.0432),
        ScatterInstance(assetName: "foliage_grass_01", position: [-16.3773, 0.0000, -18.7744], scale: 1.4952),
        ScatterInstance(assetName: "foliage_grass_01", position: [-38.4583, 1.4361, -8.3457], scale: 0.8715),
        ScatterInstance(assetName: "foliage_grass_01", position: [-16.8166, 0.1938, -25.5532], scale: 0.9130),
        ScatterInstance(assetName: "foliage_grass_01", position: [57.4294, 3.0438, -8.3928], scale: 0.9026),
        ScatterInstance(assetName: "foliage_grass_01", position: [-20.3108, 0.0000, 5.6488], scale: 1.4850),
        ScatterInstance(assetName: "foliage_grass_01", position: [31.2629, 1.6174, 36.2222], scale: 1.0567),
        ScatterInstance(assetName: "foliage_grass_01", position: [25.3348, 1.7169, -44.1211], scale: 1.3453),
        ScatterInstance(assetName: "foliage_grass_01", position: [-13.8797, 0.0679, -25.3735], scale: 1.4894),
        ScatterInstance(assetName: "foliage_grass_01", position: [31.4016, 1.9498, 41.7526], scale: 1.3179),
        ScatterInstance(assetName: "foliage_grass_01", position: [5.9280, 1.0686, -40.2716], scale: 0.8203),
        ScatterInstance(assetName: "foliage_grass_01", position: [30.6977, 0.2844, -5.4445], scale: 1.2848),
        ScatterInstance(assetName: "foliage_grass_01", position: [25.5570, 0.1140, -12.6721], scale: 1.4533),
        ScatterInstance(assetName: "foliage_grass_01", position: [40.4223, 2.7301, 37.5481], scale: 0.9104),
        ScatterInstance(assetName: "foliage_grass_01", position: [24.1785, 2.6038, 41.6295], scale: 1.4911),
        ScatterInstance(assetName: "foliage_grass_01", position: [-11.5254, 0.0000, 16.7266], scale: 1.0096),
        ScatterInstance(assetName: "foliage_grass_01", position: [-29.7991, 3.2190, 49.2427], scale: 0.8808),
        ScatterInstance(assetName: "foliage_grass_01", position: [32.9554, 0.5742, -26.2448], scale: 1.2234),
        ScatterInstance(assetName: "foliage_grass_01", position: [-5.6878, -0.0059, 27.5632], scale: 0.9848),
        ScatterInstance(assetName: "foliage_grass_01", position: [-56.0676, 1.1644, -4.0470], scale: 0.8646),
        ScatterInstance(assetName: "foliage_grass_01", position: [-27.5538, 0.6029, -14.3514], scale: 1.3398),
        ScatterInstance(assetName: "foliage_grass_01", position: [-19.8503, 0.1682, 23.1277], scale: 1.1862),
        ScatterInstance(assetName: "foliage_grass_01", position: [-18.3184, 0.0000, -8.9474], scale: 1.4182),
        ScatterInstance(assetName: "foliage_grass_01", position: [34.4325, 0.8449, 23.7407], scale: 1.2078),
        ScatterInstance(assetName: "foliage_grass_01", position: [14.9943, 0.0000, -20.1264], scale: 1.4293),
        ScatterInstance(assetName: "foliage_grass_01", position: [15.5531, 3.7406, 52.1586], scale: 0.9471),
        ScatterInstance(assetName: "foliage_grass_01", position: [0.0712, 0.0000, -24.1116], scale: 1.4189),
        ScatterInstance(assetName: "foliage_grass_01", position: [-37.2918, 3.0187, -24.8744], scale: 1.4509),
        ScatterInstance(assetName: "foliage_grass_01", position: [38.9394, 2.8285, 44.3893], scale: 1.4170),
        ScatterInstance(assetName: "foliage_grass_01", position: [48.8640, 2.1204, -7.6721], scale: 1.4516),
        ScatterInstance(assetName: "foliage_grass_01", position: [17.5878, 4.0524, 51.6502], scale: 0.9868),
        ScatterInstance(assetName: "foliage_grass_01", position: [5.6596, 0.0000, 23.6562], scale: 1.4010),
        ScatterInstance(assetName: "foliage_grass_01", position: [9.0760, 2.3607, -51.8755], scale: 1.0136),
        ScatterInstance(assetName: "foliage_grass_01", position: [8.1804, 0.2174, 27.9305], scale: 0.9352),
        ScatterInstance(assetName: "foliage_grass_01", position: [-25.7675, 2.1808, -48.1079], scale: 0.9954),
        ScatterInstance(assetName: "foliage_grass_01", position: [-22.6799, 0.6874, 27.9409], scale: 1.1754),
        ScatterInstance(assetName: "foliage_grass_01", position: [22.8415, 0.0000, 9.1705], scale: 0.9250),
        ScatterInstance(assetName: "foliage_grass_01", position: [-17.6945, 0.0000, -19.9102], scale: 1.1607),
        ScatterInstance(assetName: "foliage_grass_01", position: [-9.7819, 0.0238, -26.0670], scale: 1.2069),
        ScatterInstance(assetName: "foliage_grass_01", position: [6.1726, 0.5258, -33.8566], scale: 1.3253),
        ScatterInstance(assetName: "foliage_grass_01", position: [30.4230, -0.2399, -30.5851], scale: 1.3317),
        ScatterInstance(assetName: "foliage_grass_01", position: [-13.6390, 0.5477, -34.1423], scale: 0.9420),
        ScatterInstance(assetName: "foliage_grass_01", position: [-7.2087, 0.0392, -27.3199], scale: 1.4088),
        ScatterInstance(assetName: "foliage_grass_01", position: [-9.3080, 0.0132, -25.8854], scale: 1.1450),
        ScatterInstance(assetName: "foliage_grass_01", position: [4.1829, 0.0134, -27.0701], scale: 1.1523),
        ScatterInstance(assetName: "foliage_grass_01", position: [-23.5582, 0.5153, -28.4439], scale: 1.2693),
        ScatterInstance(assetName: "foliage_grass_01", position: [10.3656, 0.4686, -32.0646], scale: 1.0721),
        ScatterInstance(assetName: "foliage_grass_01", position: [3.7918, 0.4126, -34.2906], scale: 1.1790),
        ScatterInstance(assetName: "foliage_grass_01", position: [2.2993, 0.0000, -25.2380], scale: 1.4407),
        ScatterInstance(assetName: "foliage_grass_01", position: [-10.8707, 0.0000, -21.6683], scale: 1.2093),
        ScatterInstance(assetName: "foliage_grass_01", position: [-5.8834, 0.0212, -27.7632], scale: 1.3507),
        ScatterInstance(assetName: "foliage_grass_01", position: [-6.8678, 0.0000, -24.6782], scale: 0.9147),
        // foliage_reed_01 (36 instances)
        ScatterInstance(assetName: "foliage_reed_01", position: [28.4807, -0.1430, 7.9812], scale: 1.1940),
        ScatterInstance(assetName: "foliage_reed_01", position: [27.7689, -0.1014, 8.0675], scale: 0.8134),
        ScatterInstance(assetName: "foliage_reed_01", position: [9.0817, 0.0278, -26.1001], scale: 1.1502),
        ScatterInstance(assetName: "foliage_reed_01", position: [16.0557, 0.1837, 25.1473], scale: 1.0998),
        ScatterInstance(assetName: "foliage_reed_01", position: [26.9502, 0.2340, -15.8877], scale: 1.0912),
        ScatterInstance(assetName: "foliage_reed_01", position: [0.0263, 0.0421, 29.8243], scale: 1.0946),
        ScatterInstance(assetName: "foliage_reed_01", position: [-16.0592, 0.2794, -28.1476], scale: 0.8979),
        ScatterInstance(assetName: "foliage_reed_01", position: [-27.3332, 0.8265, -19.4971], scale: 0.7850),
        ScatterInstance(assetName: "foliage_reed_01", position: [18.9918, -0.0115, -19.4846], scale: 1.1033),
        ScatterInstance(assetName: "foliage_reed_01", position: [19.7975, -0.2229, -25.9154], scale: 1.0286),
        ScatterInstance(assetName: "foliage_reed_01", position: [-17.9253, 0.1711, -24.5396], scale: 0.7071),
        ScatterInstance(assetName: "foliage_reed_01", position: [30.6770, -0.3013, 5.6743], scale: 1.1668),
        ScatterInstance(assetName: "foliage_reed_01", position: [-30.1632, 0.8672, -13.3215], scale: 0.8055),
        ScatterInstance(assetName: "foliage_reed_01", position: [-0.3268, -0.0328, -28.3419], scale: 0.9932),
        ScatterInstance(assetName: "foliage_reed_01", position: [-1.7261, -0.0700, -29.3013], scale: 1.1550),
        ScatterInstance(assetName: "foliage_reed_01", position: [-18.0024, 0.1157, -23.5784], scale: 1.1521),
        ScatterInstance(assetName: "foliage_reed_01", position: [0.9485, 0.0017, -29.2609], scale: 0.7364),
        ScatterInstance(assetName: "foliage_reed_01", position: [-26.3421, 0.5391, -15.7038], scale: 1.0482),
        ScatterInstance(assetName: "foliage_reed_01", position: [-27.1789, -0.0100, -0.9606], scale: 0.7028),
        ScatterInstance(assetName: "foliage_reed_01", position: [0.1935, 0.1222, 31.9298], scale: 0.9126),
        ScatterInstance(assetName: "foliage_reed_01", position: [15.0968, 0.4780, -30.0417], scale: 0.7251),
        ScatterInstance(assetName: "foliage_reed_01", position: [0.1644, -0.0162, -32.6346], scale: 1.1007),
        ScatterInstance(assetName: "foliage_reed_01", position: [-16.7772, 0.5631, 29.4470], scale: 1.1750),
        ScatterInstance(assetName: "foliage_reed_01", position: [23.6847, 0.1864, 19.2388], scale: 0.9524),
        ScatterInstance(assetName: "foliage_reed_01", position: [14.5130, 0.3000, 26.1769], scale: 1.0718),
        ScatterInstance(assetName: "foliage_reed_01", position: [-26.9874, 0.0103, -4.3310], scale: 1.0188),
        ScatterInstance(assetName: "foliage_reed_01", position: [2.9453, 0.1705, 29.5453], scale: 0.8373),
        ScatterInstance(assetName: "foliage_reed_01", position: [24.3681, 0.0301, -12.8990], scale: 0.8599),
        ScatterInstance(assetName: "foliage_reed_01", position: [-1.6455, 0.0000, -26.0551], scale: 1.0123),
        ScatterInstance(assetName: "foliage_reed_01", position: [-8.1285, 0.0000, -24.1844], scale: 0.9442),
        ScatterInstance(assetName: "foliage_reed_01", position: [3.5162, 0.0000, -26.4217], scale: 1.1072),
        ScatterInstance(assetName: "foliage_reed_01", position: [-4.0249, -0.0399, -30.2980], scale: 1.0445),
        ScatterInstance(assetName: "foliage_reed_01", position: [4.6786, 0.0000, -24.6063], scale: 1.0391),
        ScatterInstance(assetName: "foliage_reed_01", position: [-17.1982, 0.3276, -27.7267], scale: 1.0364),
        ScatterInstance(assetName: "foliage_reed_01", position: [-2.1594, -0.0794, -29.7477], scale: 0.7987),
        ScatterInstance(assetName: "foliage_reed_01", position: [2.5388, 0.0000, -25.1041], scale: 1.0056),
        // rock_shoreline_03 (7 instances)
        ScatterInstance(assetName: "rock_shoreline_03", position: [-14.3933, 0.2223, -28.7681], scale: 1.2570),
        ScatterInstance(assetName: "rock_shoreline_03", position: [34.2338, 0.8018, -22.9927], scale: 0.6688),
        ScatterInstance(assetName: "rock_shoreline_03", position: [-29.6513, 1.1474, -16.7472], scale: 1.2615),
        ScatterInstance(assetName: "rock_shoreline_03", position: [23.9997, -0.1160, -23.6410], scale: 0.6495),
        ScatterInstance(assetName: "rock_shoreline_03", position: [-12.9132, 0.3119, 28.3629], scale: 0.8979),
        ScatterInstance(assetName: "rock_shoreline_03", position: [-14.0529, 1.4333, -43.4668], scale: 0.6655),
        ScatterInstance(assetName: "rock_shoreline_03", position: [34.5768, 0.4367, 15.4110], scale: 1.0465),
        // rock_shoreline_01 (21 instances)
        ScatterInstance(assetName: "rock_shoreline_01", position: [-25.8057, 0.0829, 15.3802], scale: 1.2868),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-7.8892, 0.2282, -31.0426], scale: 1.0482),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-28.9645, 0.0252, 8.9594], scale: 0.9971),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-28.4754, 1.0473, -19.9805], scale: 0.7741),
        ScatterInstance(assetName: "rock_shoreline_01", position: [13.5653, 0.8452, -34.3938], scale: 0.7950),
        ScatterInstance(assetName: "rock_shoreline_01", position: [0.0565, 0.3309, -46.4653], scale: 1.2029),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-27.5734, 0.0037, 9.0215], scale: 1.1852),
        ScatterInstance(assetName: "rock_shoreline_01", position: [45.6473, -0.9748, 9.0064], scale: 0.7164),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-32.1437, 0.0244, -2.9079], scale: 0.6410),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-34.5649, 1.2257, -32.8808], scale: 1.1488),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-35.0130, 1.3024, -10.1702], scale: 1.2968),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-39.7936, 0.4423, 14.5440], scale: 0.8077),
        ScatterInstance(assetName: "rock_shoreline_01", position: [38.8210, -0.8474, 7.7323], scale: 1.1236),
        ScatterInstance(assetName: "rock_shoreline_01", position: [37.1512, 1.8869, -13.9490], scale: 1.1969),
        ScatterInstance(assetName: "rock_shoreline_01", position: [25.9391, 0.5147, -39.4522], scale: 0.7301),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-5.3453, 0.0645, -35.5404], scale: 0.6719),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-17.5936, 0.1908, -25.0092], scale: 0.9716),
        ScatterInstance(assetName: "rock_shoreline_01", position: [4.4031, 0.4810, -34.5162], scale: 1.1608),
        ScatterInstance(assetName: "rock_shoreline_01", position: [16.3314, 0.7482, -32.5893], scale: 0.8375),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-8.3260, 0.2030, -30.1204], scale: 1.0511),
        ScatterInstance(assetName: "rock_shoreline_01", position: [20.6722, -0.2764, -26.0154], scale: 1.1977),
        // rock_shoreline_02 (4 instances)
        ScatterInstance(assetName: "rock_shoreline_02", position: [-44.4246, 0.6903, 8.9731], scale: 0.9625),
        ScatterInstance(assetName: "rock_shoreline_02", position: [-12.2331, 0.8476, -37.4501], scale: 0.8304),
        ScatterInstance(assetName: "rock_shoreline_02", position: [31.2355, -0.2323, 3.9111], scale: 0.8736),
        ScatterInstance(assetName: "rock_shoreline_02", position: [11.2311, 2.5121, 44.7991], scale: 1.0755),
        // tree_01 (26 instances)
        ScatterInstance(assetName: "tree_01", position: [33.5463, 0.6465, -1.4040], scale: 1.1419),
        ScatterInstance(assetName: "tree_01", position: [84.4054, 8.2412, -25.6176], scale: 0.7179),
        ScatterInstance(assetName: "tree_01", position: [58.8251, 4.9049, -24.7955], scale: 1.0899),
        ScatterInstance(assetName: "tree_01", position: [37.2526, 4.6859, -66.2241], scale: 1.2743),
        ScatterInstance(assetName: "tree_01", position: [15.1371, 0.9663, -34.6837], scale: 1.0622),
        ScatterInstance(assetName: "tree_01", position: [-14.3485, 0.3811, -31.7997], scale: 0.7479),
        ScatterInstance(assetName: "tree_01", position: [-19.1945, 0.7420, -33.2159], scale: 0.9189),
        ScatterInstance(assetName: "tree_01", position: [-32.6392, 0.9760, -31.2670], scale: 1.0888),
        ScatterInstance(assetName: "tree_01", position: [-19.8463, 0.2295, 23.8149], scale: 0.8339),
        ScatterInstance(assetName: "tree_01", position: [-4.8452, 1.0186, 56.8619], scale: 0.7522),
        ScatterInstance(assetName: "tree_01", position: [-27.5131, 0.6286, -14.6957], scale: 1.0032),
        ScatterInstance(assetName: "tree_01", position: [-46.2710, 0.1679, 3.8400], scale: 0.8606),
        ScatterInstance(assetName: "tree_01", position: [37.4272, 0.9188, -6.2987], scale: 1.0270),
        ScatterInstance(assetName: "tree_01", position: [9.8924, 2.4773, -52.6493], scale: 0.7039),
        ScatterInstance(assetName: "tree_01", position: [19.9019, 4.6296, 54.3993], scale: 0.7933),
        ScatterInstance(assetName: "tree_01", position: [41.9026, -0.7483, 11.5445], scale: 0.7580),
        ScatterInstance(assetName: "tree_01", position: [31.1344, 2.2932, 44.3031], scale: 1.1378),
        ScatterInstance(assetName: "tree_01", position: [-67.1467, 3.0818, 15.5540], scale: 1.0312),
        ScatterInstance(assetName: "tree_01", position: [26.1920, 3.7110, 48.0680], scale: 1.0464),
        ScatterInstance(assetName: "tree_01", position: [-9.0895, 0.0700, -27.3059], scale: 0.9158),
        ScatterInstance(assetName: "tree_01", position: [15.3698, 2.0474, 35.8739], scale: 1.2723),
        ScatterInstance(assetName: "tree_01", position: [19.5952, -0.2151, -25.2449], scale: 0.9112),
        ScatterInstance(assetName: "tree_01", position: [-7.2345, 0.2679, -33.4283], scale: 0.8838),
        ScatterInstance(assetName: "tree_01", position: [15.7206, 1.6213, -41.0135], scale: 1.0437),
        ScatterInstance(assetName: "tree_01", position: [19.9513, 0.8187, -35.1242], scale: 0.9518),
        ScatterInstance(assetName: "tree_01", position: [-27.0362, 0.4686, -27.9410], scale: 1.0738),
        // Originally "tree_02" (36 instances, authored positions/scales unchanged). `tree_02.usdz`'s
        // trunk mesh has a long-standing, still-unresolved defect (CP41 in the asset repo's
        // CHECKPOINT.md): a humanoid shape fused directly into the trunk's own mesh island, not a
        // separate object. CP41 already tried radius-per-height-band analysis and concluded no
        // purely geometric rule cleanly separates the vestige from legitimate trunk taper — it
        // flagged the fix as needing an interactive Blender vertex-selection pass, which isn't
        // available in this session either. Rather than risk further fragile per-vertex surgery on
        // a mesh already proven resistant to it, this reassigns every authored tree_02 slot to
        // tree_01 instead — same positions/scales/density, just a different (clean) mesh per slot.
        // `tree_02.usdz` itself is untouched and still has the defect; it's just not used in this
        // scatter until it's actually fixed at the source.
        //
        // A prior quick-fix here had alternated these slots between tree_01 and tree_03 (palm) —
        // that made palms *more* common scene-wide, the opposite of the user's explicit
        // temperate-only-mix request. All tree_03 slots below (both these and the originally-
        // authored ones further down) are now tree_01 — see the per-instance yaw-rotation pass in
        // `build()` for how visual variety is recovered without palms or a second tree species.
        ScatterInstance(assetName: "tree_01", position: [33.9341, 0.3674, -30.8895], scale: 0.7039),
        ScatterInstance(assetName: "tree_01", position: [2.2369, 3.8823, -77.9410], scale: 0.9271),
        ScatterInstance(assetName: "tree_01", position: [-11.4600, 4.2672, -83.4695], scale: 1.0464),
        ScatterInstance(assetName: "tree_01", position: [-38.5118, 2.8557, -18.6310], scale: 0.9277),
        ScatterInstance(assetName: "tree_01", position: [-71.9952, 3.2161, -6.8460], scale: 1.2057),
        ScatterInstance(assetName: "tree_01", position: [44.3119, 5.7362, 67.1345], scale: 0.7193),
        ScatterInstance(assetName: "tree_01", position: [-80.6163, 6.0560, 39.1423], scale: 0.8480),
        ScatterInstance(assetName: "tree_01", position: [-18.9498, 1.3818, -43.4507], scale: 1.2657),
        ScatterInstance(assetName: "tree_01", position: [-35.7434, 0.4690, 32.8600], scale: 0.9396),
        ScatterInstance(assetName: "tree_01", position: [35.9817, 2.2034, 35.3685], scale: 0.9374),
        ScatterInstance(assetName: "tree_01", position: [-60.2520, 7.6631, 73.2479], scale: 0.7283),
        ScatterInstance(assetName: "tree_01", position: [51.4074, 2.4867, 30.5998], scale: 0.8480),
        ScatterInstance(assetName: "tree_01", position: [-33.0051, 4.8412, 63.4593], scale: 0.7381),
        ScatterInstance(assetName: "tree_01", position: [-43.6216, 0.8888, 17.7063], scale: 1.2387),
        ScatterInstance(assetName: "tree_01", position: [-14.7543, 5.3449, 93.5999], scale: 1.2165),
        ScatterInstance(assetName: "tree_01", position: [-35.7055, 2.4528, -26.1476], scale: 1.0057),
        ScatterInstance(assetName: "tree_01", position: [-1.9911, 3.7763, 77.3799], scale: 0.8601),
        ScatterInstance(assetName: "tree_01", position: [27.8140, 0.2861, -17.8750], scale: 1.0765),
        ScatterInstance(assetName: "tree_01", position: [15.0105, 3.9168, 55.4444], scale: 0.9290),
        ScatterInstance(assetName: "tree_01", position: [31.9287, 1.7116, 36.6318], scale: 1.2476),
        ScatterInstance(assetName: "tree_01", position: [64.3733, 2.2772, 1.5691], scale: 1.2165),
        ScatterInstance(assetName: "tree_01", position: [41.5281, 1.6943, 29.2620], scale: 0.7917),
        ScatterInstance(assetName: "tree_01", position: [76.6471, 5.7229, -5.5387], scale: 1.0222),
        ScatterInstance(assetName: "tree_01", position: [60.6544, 2.9268, 25.9715], scale: 0.7003),
        ScatterInstance(assetName: "tree_01", position: [-7.5618, 2.5304, -71.2624], scale: 0.9609),
        ScatterInstance(assetName: "tree_01", position: [-88.1365, 9.0811, -26.3743], scale: 0.8580),
        ScatterInstance(assetName: "tree_01", position: [-41.6121, -0.3360, 0.1532], scale: 1.2223),
        ScatterInstance(assetName: "tree_01", position: [-21.4387, 4.2836, -68.2435], scale: 0.7917),
        ScatterInstance(assetName: "tree_01", position: [-15.9770, 0.7381, -36.5248], scale: 0.9652),
        ScatterInstance(assetName: "tree_01", position: [24.8193, -0.1587, -24.8640], scale: 1.1645),
        ScatterInstance(assetName: "tree_01", position: [-25.9456, 1.6140, -38.3432], scale: 0.7290),
        ScatterInstance(assetName: "tree_01", position: [-27.3217, 1.8647, -40.4744], scale: 0.9430),
        ScatterInstance(assetName: "tree_01", position: [28.0123, -0.6214, -34.8766], scale: 0.7642),
        ScatterInstance(assetName: "tree_01", position: [1.5564, 0.3387, -40.0655], scale: 1.1362),
        ScatterInstance(assetName: "tree_01", position: [3.9336, 0.3082, -32.4218], scale: 1.0650),
        ScatterInstance(assetName: "tree_01", position: [15.7689, 0.5822, -31.0871], scale: 1.0249),
        // Originally authored as real tree_03 (palm, 10 instances) in preview_scene.blend — also
        // reassigned to tree_01 now, for the same temperate-only-mix reason as the block above.
        ScatterInstance(assetName: "tree_01", position: [-56.4947, 4.9874, -23.1517], scale: 0.9899),
        ScatterInstance(assetName: "tree_01", position: [-34.3230, 3.6106, -55.5502], scale: 0.9881),
        ScatterInstance(assetName: "tree_01", position: [61.2257, 4.9496, -29.2786], scale: 1.2622),
        ScatterInstance(assetName: "tree_01", position: [21.7722, 0.3867, 26.4411], scale: 1.1676),
        ScatterInstance(assetName: "tree_01", position: [8.4535, 0.8627, -36.9849], scale: 1.1284),
        ScatterInstance(assetName: "tree_01", position: [-75.9436, 5.3835, -13.1702], scale: 0.9762),
        ScatterInstance(assetName: "tree_01", position: [45.8189, 2.0919, -31.9579], scale: 1.0868),
        ScatterInstance(assetName: "tree_01", position: [-9.2291, 2.3305, 69.7943], scale: 0.9394),
        ScatterInstance(assetName: "tree_01", position: [-90.3082, 5.6139, 14.1069], scale: 1.0933),
        ScatterInstance(assetName: "tree_01", position: [31.7974, -0.2199, 9.6418], scale: 1.1990),
        // --- App-side tree density pass (NOT from preview_scene.blend) ---
        // ~36% more tree_01 instances (26 added to the 72 above), addressing the "too few trees"
        // complaint. Each new instance is placed at a jittered interpolation between two nearby
        // *authored* trees (picked within ~14 m of each other) rather than a fresh random point —
        // both position and y-height are interpolated from the two real source instances (plus a
        // small +/-0.15 m y jitter), so every new tree sits at a plausible ground height near
        // trees already known to be correctly planted, without needing terrain raycasting.
        ScatterInstance(assetName: "tree_01", position: [-33.7318, 1.5603, -28.0284], scale: 0.9206),
        ScatterInstance(assetName: "tree_01", position: [22.8138, -0.3621, -32.2099], scale: 0.8766),
        ScatterInstance(assetName: "tree_01", position: [25.2258, -0.0646, -36.8104], scale: 0.9901),
        ScatterInstance(assetName: "tree_01", position: [-22.9369, 1.2693, -36.4294], scale: 0.9524),
        ScatterInstance(assetName: "tree_01", position: [24.0296, 0.0976, -22.9904], scale: 1.156),
        ScatterInstance(assetName: "tree_01", position: [0.1703, 0.1066, -33.1933], scale: 1.0285),
        ScatterInstance(assetName: "tree_01", position: [16.7146, 0.7483, -33.5287], scale: 0.9422),
        ScatterInstance(assetName: "tree_01", position: [24.0401, -0.1048, -25.8641], scale: 1.0248),
        ScatterInstance(assetName: "tree_01", position: [10.9692, 0.885, -37.9829], scale: 1.1061),
        ScatterInstance(assetName: "tree_01", position: [11.7087, 2.0615, -46.6829], scale: 0.9946),
        ScatterInstance(assetName: "tree_01", position: [-24.6639, 1.1196, -32.8454], scale: 1.0706),
        ScatterInstance(assetName: "tree_01", position: [35.517, -0.4206, 9.3492], scale: 0.7382),
        ScatterInstance(assetName: "tree_01", position: [4.3536, 0.6062, -39.2634], scale: 1.0881),
        ScatterInstance(assetName: "tree_01", position: [24.6726, -0.3592, -26.8928], scale: 1.0511),
        ScatterInstance(assetName: "tree_01", position: [40.3945, 2.0506, 33.1563], scale: 0.904),
        ScatterInstance(assetName: "tree_01", position: [35.9427, 1.7388, 31.5737], scale: 1.2713),
        ScatterInstance(assetName: "tree_01", position: [-16.3122, 0.5464, -32.6968], scale: 0.8011),
        ScatterInstance(assetName: "tree_01", position: [26.5032, 3.0461, 41.9983], scale: 1.1007),
        ScatterInstance(assetName: "tree_01", position: [20.4744, 0.0239, -24.0508], scale: 0.9204),
        ScatterInstance(assetName: "tree_01", position: [-16.9622, 1.1234, -41.3837], scale: 1.1682),
        ScatterInstance(assetName: "tree_01", position: [-3.747, 3.4664, 72.5784], scale: 0.9459),
        ScatterInstance(assetName: "tree_01", position: [31.5511, 2.3817, 40.382], scale: 0.9811),
        ScatterInstance(assetName: "tree_01", position: [22.0469, -0.021, -24.299], scale: 1.1965),
        ScatterInstance(assetName: "tree_01", position: [4.096, 0.3647, -38.2931], scale: 1.1718),
        ScatterInstance(assetName: "tree_01", position: [4.5872, 0.4733, -34.5782], scale: 1.0833),
        ScatterInstance(assetName: "tree_01", position: [15.4428, 1.1755, -35.3346], scale: 0.9598),
        // --- App-side shoreline densification (NOT from preview_scene.blend) ---
        // The authored scatter leaves the far-shore waterline the camera actually faces
        // (camera [0, 2.4, -1.5] looking -Z; water sheet |x|<40, |z|<30) sparse — grass/reed
        // clumps sit tens of meters apart, so the shoreline reads as bare dirt meeting water.
        // These extra instances thicken only that visible arc (far shore z ~ -22..-36 plus the
        // side shorelines at |x| ~ 30..38); y values are interpolated from nearby *authored*
        // instances so nothing floats above or sinks below the terrain it stands on.
        // foliage_reed_01 along the far waterline (reeds grow *at* the water's edge)
        ScatterInstance(assetName: "foliage_reed_01", position: [-24.5, 0.35, -24.8], scale: 1.15),
        ScatterInstance(assetName: "foliage_reed_01", position: [-21.8, 0.28, -26.9], scale: 0.92),
        ScatterInstance(assetName: "foliage_reed_01", position: [-19.4, 0.18, -25.6], scale: 1.28),
        ScatterInstance(assetName: "foliage_reed_01", position: [-13.2, 0.10, -27.8], scale: 1.05),
        ScatterInstance(assetName: "foliage_reed_01", position: [-11.6, 0.02, -24.9], scale: 0.85),
        ScatterInstance(assetName: "foliage_reed_01", position: [-9.9, 0.00, -28.7], scale: 1.22),
        ScatterInstance(assetName: "foliage_reed_01", position: [-6.4, 0.00, -26.3], scale: 0.98),
        ScatterInstance(assetName: "foliage_reed_01", position: [-3.1, 0.00, -28.9], scale: 1.10),
        ScatterInstance(assetName: "foliage_reed_01", position: [-0.9, 0.00, -27.1], scale: 0.88),
        ScatterInstance(assetName: "foliage_reed_01", position: [1.8, 0.00, -28.2], scale: 1.18),
        ScatterInstance(assetName: "foliage_reed_01", position: [5.6, 0.00, -27.4], scale: 0.95),
        ScatterInstance(assetName: "foliage_reed_01", position: [7.9, 0.02, -25.2], scale: 1.25),
        ScatterInstance(assetName: "foliage_reed_01", position: [10.7, 0.10, -28.9], scale: 1.02),
        ScatterInstance(assetName: "foliage_reed_01", position: [13.8, 0.15, -26.6], scale: 0.90),
        ScatterInstance(assetName: "foliage_reed_01", position: [16.9, 0.05, -24.3], scale: 1.12),
        ScatterInstance(assetName: "foliage_reed_01", position: [21.3, -0.10, -24.7], scale: 1.20),
        ScatterInstance(assetName: "foliage_reed_01", position: [23.9, -0.15, -26.1], scale: 0.93),
        ScatterInstance(assetName: "foliage_reed_01", position: [26.8, 0.10, -22.9], scale: 1.08),
        // side shorelines (left/right edges of the visible arc)
        ScatterInstance(assetName: "foliage_reed_01", position: [-28.9, 0.55, -18.6], scale: 1.05),
        ScatterInstance(assetName: "foliage_reed_01", position: [-30.8, 0.85, -12.4], scale: 0.90),
        ScatterInstance(assetName: "foliage_reed_01", position: [29.4, 0.15, -10.9], scale: 1.10),
        ScatterInstance(assetName: "foliage_reed_01", position: [30.9, 0.05, -5.8], scale: 0.95),
        // foliage_grass_01 just behind the waterline (bank side of the reeds)
        ScatterInstance(assetName: "foliage_grass_01", position: [-26.7, 0.75, -28.4], scale: 1.30),
        ScatterInstance(assetName: "foliage_grass_01", position: [-22.4, 0.55, -30.6], scale: 1.10),
        ScatterInstance(assetName: "foliage_grass_01", position: [-18.9, 0.30, -29.8], scale: 1.45),
        ScatterInstance(assetName: "foliage_grass_01", position: [-15.3, 0.20, -31.9], scale: 0.95),
        ScatterInstance(assetName: "foliage_grass_01", position: [-12.1, 0.25, -29.4], scale: 1.35),
        ScatterInstance(assetName: "foliage_grass_01", position: [-8.6, 0.15, -31.2], scale: 1.05),
        ScatterInstance(assetName: "foliage_grass_01", position: [-4.9, 0.20, -30.4], scale: 1.40),
        ScatterInstance(assetName: "foliage_grass_01", position: [-1.6, 0.10, -29.6], scale: 0.90),
        ScatterInstance(assetName: "foliage_grass_01", position: [2.7, 0.15, -30.8], scale: 1.25),
        ScatterInstance(assetName: "foliage_grass_01", position: [6.3, 0.30, -32.1], scale: 1.08),
        ScatterInstance(assetName: "foliage_grass_01", position: [9.4, 0.35, -30.2], scale: 1.42),
        ScatterInstance(assetName: "foliage_grass_01", position: [12.8, 0.45, -32.6], scale: 1.00),
        ScatterInstance(assetName: "foliage_grass_01", position: [16.2, 0.55, -30.9], scale: 1.30),
        ScatterInstance(assetName: "foliage_grass_01", position: [19.7, 0.40, -28.8], scale: 0.92),
        ScatterInstance(assetName: "foliage_grass_01", position: [23.4, 0.30, -27.6], scale: 1.20),
        ScatterInstance(assetName: "foliage_grass_01", position: [27.2, 0.50, -25.4], scale: 1.10),
        ScatterInstance(assetName: "foliage_grass_01", position: [-30.2, 1.00, -22.7], scale: 1.15),
        ScatterInstance(assetName: "foliage_grass_01", position: [-32.6, 1.30, -16.9], scale: 0.95),
        ScatterInstance(assetName: "foliage_grass_01", position: [31.6, 0.40, -13.8], scale: 1.25),
        ScatterInstance(assetName: "foliage_grass_01", position: [32.8, 0.30, -8.2], scale: 1.05),
        // a few extra rocks breaking up the waterline
        ScatterInstance(assetName: "rock_shoreline_01", position: [-16.8, 0.12, -26.4], scale: 0.85),
        ScatterInstance(assetName: "rock_shoreline_01", position: [-2.3, 0.00, -27.9], scale: 0.68),
        ScatterInstance(assetName: "rock_shoreline_01", position: [12.1, 0.08, -27.3], scale: 0.95),
        ScatterInstance(assetName: "rock_shoreline_01", position: [24.9, -0.05, -23.8], scale: 0.72),
        ScatterInstance(assetName: "rock_shoreline_03", position: [-25.9, 0.40, -26.2], scale: 0.78),
        ScatterInstance(assetName: "rock_shoreline_03", position: [8.3, 0.05, -26.8], scale: 0.65),
        ScatterInstance(assetName: "rock_shoreline_02", position: [-29.7, 0.70, -20.3], scale: 0.88),
        ScatterInstance(assetName: "rock_shoreline_02", position: [30.1, 0.10, -8.9], scale: 0.80),
        // --- foliage_fern_01 (NEW asset, ~6,200 tris, alpha-cutout — cheap, scattered liberally) ---
        // 42 instances, generated the same interpolate-between-two-nearby-anchors-plus-jitter way
        // as the tree density pass above, but anchored on the existing foliage_grass_01/
        // foliage_reed_01 instances (148 combined) instead of trees — keeps ferns concentrated in
        // the same shoreline/undergrowth band those already occupy, at plausible ground height.
        ScatterInstance(assetName: "foliage_fern_01", position: [-27.2837, 0.8016, -19.6095], scale: 1.2519),
        ScatterInstance(assetName: "foliage_fern_01", position: [-28.5418, 0.6857, -17.9011], scale: 0.9504),
        ScatterInstance(assetName: "foliage_fern_01", position: [-17.007, 0.2672, -27.4544], scale: 1.1657),
        ScatterInstance(assetName: "foliage_fern_01", position: [-8.462, 0.0191, -24.8021], scale: 1.1003),
        ScatterInstance(assetName: "foliage_fern_01", position: [2.8866, 0.1619, -31.2108], scale: 1.1166),
        ScatterInstance(assetName: "foliage_fern_01", position: [-2.1911, -0.0277, -26.7572], scale: 0.8357),
        ScatterInstance(assetName: "foliage_fern_01", position: [-2.3276, 0.0647, -30.0162], scale: 0.8975),
        ScatterInstance(assetName: "foliage_fern_01", position: [-10.5992, 0.2167, -26.9728], scale: 1.1592),
        ScatterInstance(assetName: "foliage_fern_01", position: [20.1742, -0.0107, -18.7727], scale: 1.0137),
        ScatterInstance(assetName: "foliage_fern_01", position: [-11.9062, -0.0403, -25.8422], scale: 0.8412),
        ScatterInstance(assetName: "foliage_fern_01", position: [-21.1938, 0.3018, -27.5646], scale: 1.1079),
        ScatterInstance(assetName: "foliage_fern_01", position: [-7.6854, 0.1967, -30.4223], scale: 1.05),
        ScatterInstance(assetName: "foliage_fern_01", position: [4.3501, 0.5026, -34.5405], scale: 1.1581),
        ScatterInstance(assetName: "foliage_fern_01", position: [-7.6631, -0.0352, -25.2391], scale: 1.2551),
        ScatterInstance(assetName: "foliage_fern_01", position: [8.5862, 0.071, -27.6597], scale: 0.9978),
        ScatterInstance(assetName: "foliage_fern_01", position: [-0.1365, 0.0721, -29.9753], scale: 0.974),
        ScatterInstance(assetName: "foliage_fern_01", position: [18.6112, 0.4128, -31.4679], scale: 0.7575),
        ScatterInstance(assetName: "foliage_fern_01", position: [-2.7527, 0.0869, -30.1679], scale: 0.9493),
        ScatterInstance(assetName: "foliage_fern_01", position: [-5.5349, -0.0874, -29.8244], scale: 0.9848),
        ScatterInstance(assetName: "foliage_fern_01", position: [-20.3485, 0.1746, -25.8428], scale: 1.0453),
        ScatterInstance(assetName: "foliage_fern_01", position: [-1.389, -0.1266, -27.6821], scale: 1.2719),
        ScatterInstance(assetName: "foliage_fern_01", position: [-2.9386, -0.0757, -29.0381], scale: 0.9169),
        ScatterInstance(assetName: "foliage_fern_01", position: [-17.3682, 0.1015, -26.9186], scale: 1.0239),
        ScatterInstance(assetName: "foliage_fern_01", position: [29.7895, 0.362, -24.2075], scale: 0.9018),
        ScatterInstance(assetName: "foliage_fern_01", position: [-22.7374, 0.5467, -26.5393], scale: 1.0321),
        ScatterInstance(assetName: "foliage_fern_01", position: [2.8855, 0.0863, -27.0441], scale: 1.2538),
        ScatterInstance(assetName: "foliage_fern_01", position: [8.6834, 0.0744, -21.6128], scale: 1.1575),
        ScatterInstance(assetName: "foliage_fern_01", position: [-2.075, -0.0318, -29.405], scale: 1.1895),
        ScatterInstance(assetName: "foliage_fern_01", position: [9.0109, -0.0199, -26.6128], scale: 1.0425),
        ScatterInstance(assetName: "foliage_fern_01", position: [16.2879, 0.3836, -28.6573], scale: 0.8986),
        ScatterInstance(assetName: "foliage_fern_01", position: [0.5066, 0.0018, -24.7614], scale: 1.215),
        ScatterInstance(assetName: "foliage_fern_01", position: [23.0028, 0.1502, -27.5824], scale: 0.7926),
        ScatterInstance(assetName: "foliage_fern_01", position: [-8.8481, 0.0218, -24.7009], scale: 0.9588),
        ScatterInstance(assetName: "foliage_fern_01", position: [-3.8288, 0.0095, 30.2148], scale: 1.0753),
        ScatterInstance(assetName: "foliage_fern_01", position: [10.1739, 0.5456, -31.5185], scale: 1.1967),
        ScatterInstance(assetName: "foliage_fern_01", position: [-10.0717, 0.1304, -27.3098], scale: 0.7715),
        ScatterInstance(assetName: "foliage_fern_01", position: [14.4695, 0.3664, -27.022], scale: 1.0046),
        ScatterInstance(assetName: "foliage_fern_01", position: [-19.8011, 0.4311, 26.6251], scale: 0.9577),
        ScatterInstance(assetName: "foliage_fern_01", position: [-13.9925, 0.0253, -26.0997], scale: 0.9186),
        ScatterInstance(assetName: "foliage_fern_01", position: [26.1986, 0.2017, -13.5273], scale: 0.8788),
        ScatterInstance(assetName: "foliage_fern_01", position: [-22.745, 0.4869, -28.9395], scale: 1.2496),
        ScatterInstance(assetName: "foliage_fern_01", position: [7.8785, 0.378, -31.4887], scale: 1.0601),
        // --- foliage_shrub_01 (NEW asset, ~156,000 tris — confirmed real Poly Haven density, not a
        // bug; no decimation tool was available this session). Deliberately capped at 5 instances
        // (within the 4-6 target) rather than scattered widely — each instance costs roughly 40x a
        // single tree_01 in triangle budget, so a wide scatter would be a very real perf risk.
        // Placed at visually prominent spots only: two flanking the dock (where the player looks
        // most), and three breaking up the near shoreline rocks already in view, not buried deep
        // in the treeline where the cost would be wasted off-camera.
        ScatterInstance(assetName: "foliage_shrub_01", position: [-3.2, 0.75, 1.5], scale: 1.0),
        ScatterInstance(assetName: "foliage_shrub_01", position: [3.6, 0.70, 0.8], scale: 1.05),
        ScatterInstance(assetName: "foliage_shrub_01", position: [-15.5, 0.15, -25.0], scale: 0.95),
        ScatterInstance(assetName: "foliage_shrub_01", position: [23.5, -0.02, -22.5], scale: 1.1),
        ScatterInstance(assetName: "foliage_shrub_01", position: [-28.0, 0.65, -19.0], scale: 1.0),
    ]

    /// Every scattered instance previously shared identical (`.identity`) rotation — a visible
    /// "stamped clone" tell, especially obvious across ~98 near-identical tree_01 silhouettes all
    /// facing the same way. Applied only to vertical/asymmetric assets where yaw is actually
    /// visible (trees, fern, shrub); skipped for grass/reed/rocks, which read the same from any
    /// yaw and aren't worth the (harmless but pointless) extra rotation.
    private static let yawRandomizedAssetNames: Set<String> = [
        "tree_01", "foliage_fern_01", "foliage_shrub_01"
    ]

    /// Deterministic pseudo-random yaw (radians) derived from an instance's own world position —
    /// stable across app runs (same input position always yields the same yaw, no stored seed
    /// needed), using the same classic GLSL-style hash (`sin` of a large dot product, take the
    /// fractional part) commonly used for cheap per-instance procedural variation.
    private static func deterministicYaw(for position: SIMD3<Float>) -> Float {
        let seed = sin(position.x * 12.9898 + position.z * 78.233) * 43758.5453
        let fraction = seed - floor(seed)
        return fraction * 2 * .pi
    }

    private static let deckHeight: Float = 0.80

    private struct DockProp {
        let assetName: String
        let position: SIMD3<Float>
        let yawDegrees: Float
    }

    /// Exact authored positions from `preview_scene.blend`, replacing the previous hand-guessed
    /// placements. `prop_bucket_01`/`prop_tacklebox_01` are identity rotation; `prop_rope_01` has
    /// a real ~28.65° yaw (the only dock prop with non-identity rotation in the source scene).
    private static let dockProps = [
        DockProp(assetName: "prop_bucket_01", position: [1.2, deckHeight, -1.5], yawDegrees: 0),
        DockProp(assetName: "prop_tacklebox_01", position: [-1.0, deckHeight, -1.8], yawDegrees: 0),
        DockProp(assetName: "prop_rope_01", position: [0.0, deckHeight, -2.5], yawDegrees: 28.65)
    ]

    static func build() async -> Entity {
        let root = Entity()
        root.name = "EnvironmentRoot"

        for name in coreAssetNames {
            if let entity = await load(name) {
                if name == "water_surface" {
                    WaterMaterial.apply(to: entity)
                }
                if name == "terrain_horizon_ring" {
                    tintTerrainGreen(entity)
                }
                root.addChild(entity)
            }
        }

        root.addChild(makeSun())

        if let ibl = await makeImageBasedLight() {
            root.addChild(ibl)
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ibl))
        }

        let instancesByAsset = Dictionary(grouping: scatterInstances, by: \.assetName)
        for (assetName, instances) in instancesByAsset {
            guard let template = await load(assetName) else { continue }
            let rotatesPerInstance = yawRandomizedAssetNames.contains(assetName)
            for instance in instances {
                let clone = template.clone(recursive: true)
                clone.position = instance.position
                clone.scale = SIMD3<Float>(repeating: instance.scale)
                if rotatesPerInstance {
                    // Compose the yaw with the clone's EXISTING orientation rather than replacing
                    // it outright. `tree_01`/`foliage_fern_01`/`foliage_shrub_01` (every asset in
                    // `yawRandomizedAssetNames`) load with a non-identity root orientation already
                    // baked in — the standard USD Z-up -> RealityKit Y-up import correction, quat
                    // (-0.7071, 0, 0, 0.7071), a -90° rotation about X (confirmed via a standalone
                    // transform dump: `dump_transform.swift <path>` prints exactly this quaternion
                    // as every one of these three assets' own top-level orientation). Setting
                    // `clone.orientation = simd_quatf(yaw, axis: Y)` directly, as an earlier pass
                    // here did, **replaces** that correction wholesale — erasing the up-axis fix
                    // and tipping every rotated instance onto its side (confirmed live: a zoomed
                    // screenshot showed trees as flat, horizontal branch-debris smears on the
                    // ground, not upright silhouettes; a debug-instrumented run confirmed all 98
                    // tree_01/42 fern/5 shrub clones WERE being created and added successfully, so
                    // the bug was purely this orientation overwrite, not a loading/placement fault).
                    // Left-multiplying instead applies the existing (corrective) orientation first,
                    // then the yaw around world Y on top — since the correction already maps local
                    // "up" to world +Y, a subsequent rotation around world Y leaves that mapping
                    // unchanged (rotating a vector around its own axis doesn't move it) while still
                    // spinning the rest of the mesh for visual variety, verified by hand via the
                    // standard quaternion rotation formula before applying this fix.
                    let yaw = simd_quatf(angle: deterministicYaw(for: instance.position), axis: [0, 1, 0])
                    clone.orientation = yaw * clone.orientation
                }
                root.addChild(clone)
            }
            template.removeFromParent()
        }

        for prop in dockProps {
            if let entity = await load(prop.assetName) {
                entity.position = prop.position
                entity.orientation = simd_quatf(
                    angle: prop.yawDegrees * .pi / 180,
                    axis: [0, 1, 0]
                )
                root.addChild(entity)
            }
        }

        return root
    }

    private static func load(_ name: String) async -> Entity? {
        try? await Entity(named: name)
    }

    /// Multiplies `terrain_horizon_ring`'s baked-in ground texture (Poly Haven `leafy_grass`) by a
    /// green tint. Needed because the sourced texture, while an accurate real-world ground photo
    /// (leaf litter + sparse grass), averages to a warm tan/brown (measured mean RGB ≈ (151,131,89)
    /// — red and green nearly equal, both far above blue), not the "lush green" look the user
    /// asked for — confirmed by a live screenshot showing the hillside reading as sandy desert
    /// dunes, not grass. Poly Haven's real-world-photo ground library doesn't offer a clearly
    /// green-dominant alternative (checked `grass_path_2/3`, `sparse_grass`, `forrest_ground_01/03`
    /// — all lean brown/dead-grass/leaf-litter, consistent with how real fields actually look), so
    /// rather than keep re-sourcing textures, this tints the existing one: `PhysicallyBasedMaterial
    /// .BaseColor.tint` multiplies the sampled texture color (confirmed via a standalone
    /// load-mutate-reread test before wiring this in — the tint is a real, persisted material
    /// parameter, not a no-op).
    ///
    /// **Retuned (was `(0.5, 0.85, 0.45)`) after a live screenshot showed the ground reading as an
    /// unnaturally flat, near-solid green** — the opposite of "natural." Root cause: multiplying
    /// EVERY pixel by the same tint vector pushes both the original photo's brown-dominant and
    /// green-dominant patches toward the *same* resulting hue, collapsing the natural hue variety
    /// (not just brightness) that made the source texture read as organic in the first place —
    /// confirmed by comparing per-channel std-dev before/after tinting (a linear multiply scales
    /// std-dev by the same factor per channel, so the stronger prior tint suppressed red/blue
    /// contrast far more than it needed to). Green is now left at `1.0` (untouched, preserving 100%
    /// of the original texture's own green-channel detail/variation) and red/blue are suppressed
    /// more moderately (`0.65`/`0.6`, vs. the prior `0.5`/`0.45`) — enough to shift the overall cast
    /// from tan to a clearly green "olive grass" tone without crushing as much of the underlying
    /// photo's natural patchiness. Only the diffuse-texture material is tinted; normal/roughness
    /// maps are untouched.
    private static func tintTerrainGreen(_ entity: Entity) {
        guard let model = findModelEntity(in: entity) else { return }
        guard var materials = model.model?.materials else { return }
        for i in materials.indices {
            guard var pbm = materials[i] as? PhysicallyBasedMaterial else { continue }
            pbm.baseColor.tint = NSColor(srgbRed: 0.65, green: 1.0, blue: 0.6, alpha: 1.0)
            materials[i] = pbm
        }
        model.model?.materials = materials
    }

    private static func findModelEntity(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity {
            return model
        }
        for child in entity.children {
            if let found = findModelEntity(in: child) {
                return found
            }
        }
        return nil
    }

    /// Image-based (environment) lighting, sourced from the **same** equirectangular sky texture
    /// `sky_dome.usdz` itself displays (`sky_ibl.jpg`, a standalone copy of
    /// `sky_dome_diffuse_evening_road.jpg` bundled alongside the other environment assets) — so
    /// reflections/ambient tint match what the player actually sees overhead, per AGENTS §4.6's
    /// "same HDRI drives both the visible sky and the lighting" convention, which had never
    /// actually been implemented on the app side before now (CLAUDE.md TODO #4). Without this,
    /// nothing in the scene had any ambient/reflected light at all beyond the single directional
    /// sun — most visible on `water_surface`, which had no sky to reflect and so read as a flat
    /// tinted color with only a sun speck for specular, not "water."
    ///
    /// Attached as an `ImageBasedLightReceiverComponent` on `EnvironmentRoot` itself (not per-child)
    /// so every descendant entity — water, dock, terrain, foliage, rod — picks it up by walking up
    /// to the nearest ancestor that has the component, rather than needing it set individually.
    private static func makeImageBasedLight() async -> Entity? {
        guard
            let url = Bundle.main.url(forResource: "sky_ibl", withExtension: "jpg"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        guard let resource = try? await EnvironmentResource(equirectangular: cgImage, withName: "sky_ibl")
        else { return nil }

        let entity = Entity()
        entity.name = "SkyIBL"
        // Raised from 0.5 -> 0.85 alongside the sun intensity increase in `makeSun()` — enough
        // ambient fill that shadowed faces (now that shadows actually exist, see `makeSun()`)
        // don't go pure black, without washing out the directional contrast that's the whole point
        // of adding real shadows in the first place.
        entity.components.set(ImageBasedLightComponent(source: .single(resource), intensityExponent: 0.85))
        return entity
    }

    private static func makeSun() -> Entity {
        let light = Entity()
        light.name = "SunLight"
        // Intensity raised (4000 -> 7000) and, critically, a `.Shadow` component added — without
        // one, `DirectionalLightComponent` alone casts **no shadows at all** (it's a separate,
        // opt-in component in RealityKit, easy to miss). No shadows meant nothing in the scene had
        // any contact/grounding shading — trees, rocks, and the dock all looked like they were
        // floating in uniformly flat light, a large part of the "empty and unnatural" complaint.
        // `maximumDistance: 40` covers the dock/near-shore area where shadows matter most for
        // grounding, without paying full shadow-map resolution cost out to the ~90 m scatter edge.
        // `depthBias` raised 1.5 -> 2.5: a live screenshot after the tree-orientation fix showed
        // blotchy tan/discolored patches within tree canopies that don't come from the source
        // foliage texture (confirmed clean/uniformly grey-green by inspecting it directly) — the
        // classic signature of shadow acne (self-shadowing artifacts) on thin alpha-cutout foliage
        // cards, which is exactly the kind of geometry most prone to it. A moderate depthBias
        // increase is the standard first fix; not yet re-verified live (screenshot capture still
        // blocked this session) — if the blotching persists, this is the next value to keep raising.
        light.components.set(DirectionalLightComponent(color: sunColor, intensity: 7000))
        light.components.set(
            DirectionalLightComponent.Shadow(shadowProjection: .automatic(maximumDistance: 40), depthBias: 2.5)
        )

        let elevation = sunElevationDegrees * .pi / 180
        let azimuth = sunAzimuthDegrees * .pi / 180
        let sunDirection = SIMD3<Float>(
            cos(elevation) * cos(azimuth),
            sin(elevation),
            cos(elevation) * sin(azimuth)
        )
        light.look(at: .zero, from: sunDirection * sunDistance, relativeTo: nil)
        return light
    }
}
