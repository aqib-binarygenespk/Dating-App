// lib/features/search/search_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/theme.dart';

import '../dashboard/Dashboard.dart';
import 'Searchdetail/search_profiledart.dart';
import 'Searchdetail/searchdetaildart.dart';
import 'search_controller.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final CustomSearchController controller = Get.put(CustomSearchController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.fromLTRB(5, 10, 15, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset('assets/the_pairup_logo_black.png', height: 70),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Obx(() {
            final chipWidgets = <Widget>[];
            chipWidgets.add(_buildFilterChip(controller.searchingFor.value));

            if ((controller.selectedLocationLabel.value.isNotEmpty &&
                controller.selectedLocationLabel.value != 'San Diego') ||
                controller.selectedLatLng != null) {
              chipWidgets.add(_buildFilterChip(controller.selectedLocationLabel.value));
              chipWidgets.add(_buildFilterChip('0 - ${controller.distanceMax.value.round()} Miles'));
            }
            if (controller.ageStart.value != 18 || controller.ageEnd.value != 70) {
              chipWidgets.add(_buildFilterChip(
                  '${controller.ageStart.value.round()} - ${controller.ageEnd.value.round()}'));
            }
            if (!(controller.heightStart.value == 4.0 && controller.heightEnd.value == 7.10)) {
              chipWidgets.add(_buildFilterChip(
                '${_feetInchesString(controller.heightStart.value)} - ${_feetInchesString(controller.heightEnd.value)}',
              ));
            }

            return Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: chipWidgets.expand((w) => [w, const SizedBox(width: 6)]).toList(),
                ),
              ),
            );
          }),

          // Profiles
          Expanded(
            child: Obx(() {
              final items = controller.profiles;
              if (controller.isLoading.value && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return const Center(child: Text('No profiles match your filters'));
              }

              return NotificationListener<ScrollNotification>(
                onNotification: (sn) {
                  if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 200 &&
                      !controller.isLoadingMore.value) {
                    controller.fetchProfiles(reset: false);
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: items.length + (controller.isLoadingMore.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final profile = items[index];
                    return GestureDetector(
                      onTap: () {
                        controller.selectProfile(profile);
                        (context.findAncestorStateOfType<DashboardScreenState>())
                            ?.updateSearchScreen(DetailProfileScreen(profile: profile));
                        // Or: Get.to(() => DetailProfileScreen(profile: profile));
                      },
                      child: ProfileCard(profile: profile),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- bottom sheet with filters ---
  void _showFilterBottomSheet(BuildContext context) {
    bool showAgeSlider = false;
    bool showHeightSlider = false;
    bool showDistanceSlider = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Filter", style: AppTheme.textTheme.bodyLarge),
                          const SizedBox(height: 20),

                          _buildDropdownField(
                            context,
                            "Searching For",
                            controller.searchingFor.value,
                            const ["Dating", "Social Circle"],
                                (val) => setModalState(() => controller.searchingFor.value = val),
                          ),
                          const SizedBox(height: 16),

                          // Location
                          Text("Location",
                              style:
                              AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black)),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0x66B8B8B8)),
                            ),
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.place_outlined,
                                    size: 20, color: Colors.black),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Obx(() => Text(
                                    controller.selectedLatLng == null
                                        ? controller.selectedLocationLabel.value
                                        : controller.selectedLocationLabel.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.textTheme.bodyMedium
                                        ?.copyWith(color: const Color(0x80111827)),
                                  )),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await controller.pickLocation(context);
                                    setModalState(() {}); // refresh local sheet state
                                  },
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('Choose on map'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Age range
                          Text("Age Range",
                              style:
                              AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black)),
                          const SizedBox(height: 8),
                          _expanderButton(
                            context: context,
                            label:
                            "${controller.ageStart.value.round()} - ${controller.ageEnd.value.round()}",
                            onTap: () =>
                                setModalState(() => showAgeSlider = !showAgeSlider),
                          ),
                          if (showAgeSlider)
                            _thinRangeSlider(
                              context: context,
                              values: RangeValues(controller.ageStart.value,
                                  controller.ageEnd.value),
                              min: 18,
                              max: 70,
                              divisions: 52,
                              onChanged: (v) => setModalState(() {
                                controller.ageStart.value = v.start;
                                controller.ageEnd.value = v.end;
                              }),
                              labelBuilder: (v) => RangeLabels(
                                '${v.start.round()}',
                                '${v.end.round()}',
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Height
                          Text("Height",
                              style:
                              AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black)),
                          const SizedBox(height: 8),
                          _expanderButton(
                            context: context,
                            label:
                            "${_feetInchesString(controller.heightStart.value)} - ${_feetInchesString(controller.heightEnd.value)}",
                            onTap: () => setModalState(
                                    () => showHeightSlider = !showHeightSlider),
                          ),
                          if (showHeightSlider)
                            _thinRangeSlider(
                              context: context,
                              values: RangeValues(controller.heightStart.value,
                                  controller.heightEnd.value),
                              min: 4.0,
                              max: 7.10,
                              divisions: 25,
                              onChanged: (v) => setModalState(() {
                                controller.heightStart.value = v.start;
                                controller.heightEnd.value = v.end;
                              }),
                              labelBuilder: (v) => RangeLabels(
                                _feetInchesString(v.start),
                                _feetInchesString(v.end),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Distance (discrete)
                          Text("Distance",
                              style:
                              AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black)),
                          const SizedBox(height: 8),
                          _expanderButton(
                            context: context,
                            label:
                            "0 - ${controller.distanceMax.value.round()} Miles",
                            onTap: () => setModalState(
                                    () => showDistanceSlider = !showDistanceSlider),
                          ),
                          if (showDistanceSlider)
                            _discreteDistanceSlider(
                              context: context,
                              controller: controller,
                              setModalState: setModalState,
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Apply
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await controller.applyFiltersAndSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        "Apply Filter",
                        style: AppTheme.textTheme.labelLarge?.copyWith(
                          color: AppTheme.backgroundColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---- small UI helpers ----
  Widget _buildFilterChip(String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
        color: AppTheme.backgroundColor,
      ),
      child:
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }

  Widget _thinRangeSlider({
    required BuildContext context,
    required RangeValues values,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<RangeValues> onChanged,
    required RangeLabels Function(RangeValues) labelBuilder,
  }) {
    final labels = labelBuilder(values);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 1.0,
        activeTrackColor: Colors.black,
        inactiveTrackColor: Colors.black26,
        thumbColor: Colors.black,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: SliderComponentShape.noOverlay,
        tickMarkShape: SliderTickMarkShape.noTickMark,
        trackShape: const RectangularSliderTrackShape(),
      ),
      child: RangeSlider(
        values: values,
        min: min,
        max: max,
        divisions: divisions,
        labels: labels,
        onChanged: onChanged,
      ),
    );
  }

  Widget _expanderButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66B8B8B8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.centerLeft,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: AppTheme.textTheme.bodyMedium
                    ?.copyWith(color: const Color(0x80111827))),
            const Icon(Icons.keyboard_arrow_down, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _discreteDistanceSlider({
    required BuildContext context,
    required CustomSearchController controller,
    required void Function(void Function()) setModalState,
  }) {
    final steps = CustomSearchController.distanceSteps;
    return Obx(() {
      final idx = controller.distanceIndex.value;
      final maxIdx = steps.length - 1;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live label

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              activeTrackColor: Colors.black,
              inactiveTrackColor: Colors.black26,
              thumbColor: Colors.black,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: SliderComponentShape.noOverlay,
              tickMarkShape: SliderTickMarkShape.noTickMark,
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Slider(
              min: 0,
              max: maxIdx.toDouble(),
              divisions: maxIdx,
              value: idx.toDouble(),
              onChanged: (v) => setModalState(() {
                controller.setDistanceByIndex(v.round());
              }),
            ),
          ),

          // Quick-jump chips
          const SizedBox(height: 6),
        ],
      );
    });
  }
}

// ===================== ProfileCard ===============================

class ProfileCard extends StatefulWidget {
  final SearchProfile profile;
  const ProfileCard({Key? key, required this.profile}) : super(key: key);

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _showAll = false;
  final CustomSearchController _c = Get.find<CustomSearchController>();

  String _formatHeight(num? inches) {
    if (inches == null) return 'N/A';
    final ft = inches ~/ 12;
    final inch = inches % 12;
    return "$ft'${inch.toInt()}\"";
  }

  String? _firstPhoto() =>
      widget.profile.photos.isNotEmpty ? widget.profile.photos.first.url : null;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final header = _firstPhoto();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC9C9C9), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // header image + avatar + actions
          Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: header == null
                          ? const AssetImage('assets/profilevideoimage.png')
                      as ImageProvider
                          : NetworkImage(header),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              // AVATAR
              Positioned(
                top: 130,
                child: GestureDetector(
                  onTap: () {
                    final url = _firstPhoto();
                    if (url == null) return;
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(10),
                        child: Stack(
                          children: [
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: url == null
                                    ? Image.asset('assets/dpjohn.png')
                                    : Image.network(url, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 28),
                                onPressed: () =>
                                    Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: header == null
                        ? const AssetImage('assets/dpjohn.png')
                        : NetworkImage(header) as ImageProvider,
                  ),
                ),
              ),
              // Dismiss
              Positioned(
                top: 10,
                left: 10,
                child: GestureDetector(
                  onTap: () => _c.dismissUser(p.id),
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1A26),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.close, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
              // Like
              Positioned(
                top: 10,
                right: 10,
                child: Obx(() {
                  final liked = _c.isLiked(p.id);
                  return GestureDetector(
                    onTap: () {
                      if (!liked) {
                        _c.likeUser(p.id);
                      } else {
                        Get.snackbar('Like', 'Already sent 👍');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 50),

          // name
          Text(p.name, style: AppTheme.textTheme.bodyLarge),

          // age • height • distance
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(p.age?.toString() ?? 'N/A',
                  style: AppTheme.textTheme.bodySmall),
              const SizedBox(width: 4),
              Container(width: 1, height: 14, color: Colors.black54),
              const SizedBox(width: 4),
              Text(_formatHeight(p.height),
                  style: AppTheme.textTheme.bodySmall),
              if (p.distanceMiles != null) ...[
                const SizedBox(width: 4),
                Container(width: 1, height: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Text("${p.distanceMiles!.toStringAsFixed(1)} mi",
                    style: AppTheme.textTheme.bodySmall),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // details grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(children: _buildDetailsGrid(p)),
          ),
          const SizedBox(height: 10),

          // Show All / Show Less
          ElevatedButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.backgroundColor,
              minimumSize: const Size(90, 30),
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25)),
            ),
            child: Text(
              _showAll ? "Show Less" : "Show All",
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  List<Widget> _buildDetailsGrid(SearchProfile p) {
    final details = _showAll ? _buildAllTags(p) : _buildLimitedTags(p);
    return [
      Column(
        children: [
          for (int i = 0; i < details.length; i += 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: details[i],
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[700]),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: i + 1 < details.length
                          ? details[i + 1]
                          : const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildLimitedTags(SearchProfile p) => [
    _buildTag("About Me", p.aboutMe),
    _buildTag("Bonding Moments", p.bondingMoments),
    _buildTag("Pets", p.pets),
    _buildTag("Smoking Habits", p.smokingHabits),
  ];

  List<Widget> _buildAllTags(SearchProfile p) => [
    _buildTag("About Me", p.aboutMe),
    _buildTag("Bonding Moments", p.bondingMoments),
    _buildTag("Pets", p.pets),
    _buildTag("Smoking Habits", p.smokingHabits),
    _buildTag("Drinking Habits", p.drinkingHabits),
    _buildTag("Dietary Preferences", p.dietPreferences),
    _buildTag("Love Languages", p.loveLanguage),
    _buildTag("Attachment Style", p.attachmentStyle),
    _buildTag("Relocate for Love", p.relocateForLove),
    _buildTag("Work", p.work),
    _buildTag("Kids", p.kids),
    _buildTag("Politics", p.politics),
    _buildTag("Religion", p.religion),
    _buildTag("Education", p.education),
  ];

  Widget _buildTag(String label, String? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTheme.textTheme.bodyMedium),
      const SizedBox(height: 4),
      Text(
        (value == null || value.isEmpty) ? 'N/A' : value,
        style: AppTheme.textTheme.bodySmall,
      ),
    ],
  );
}

// height label helper
String _feetInchesString(double v) {
  final feet = v.floor();
  final inches = ((v - feet) * 10).round();
  return "$feet'$inches\"";
}

Widget _buildDropdownField(
    BuildContext context,
    String label,
    String selectedValue,
    List<String> options,
    void Function(String) onSelected,
    ) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: AppTheme.textTheme.labelLarge?.copyWith(color: Colors.black)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x66B8B8B8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedValue,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
            isExpanded: true,
            borderRadius: BorderRadius.circular(8),
            dropdownColor: AppTheme.backgroundColor,
            onChanged: (String? newValue) {
              if (newValue != null) onSelected(newValue);
            },
            items: options.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    value,
                    style: AppTheme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0x80111827),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ],
  );
}
