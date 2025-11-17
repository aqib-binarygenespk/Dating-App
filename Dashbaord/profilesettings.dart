import 'package:dating_app/Auth/setup-screens/kids/kids.dart';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/attachmentstyle/editattachmentstyle.dart';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/bondingmoment/editbondingmomentsdart.dart';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/habbits/edithabbits.dart';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/lovelanguage/editlovelanguage.dart';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/relocate/editrelocate.dart';
import 'package:dating_app/Dashbaord/settingspages/profilesettings/editprofile/updatesocialmedia/updatesocialmediadart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dating_app/themesfolder/theme.dart';
import '../../../Auth/setup-screens/recordvideo/recordvideo.dart';
import '../../dashboard/Dashboard.dart';
import 'editprofile/aboutme/editaboutme.dart';
import 'editprofile/gettoknow/editgettoknow.dart';
import 'editprofile/height/editheight.dart';
import 'editprofile/interestedin/editinterestedin.dart';
import 'editprofile/newscreens/newscreens.dart';
import 'editprofile/pairupcityupdate/pairupcityupdatedart.dart';
import 'editprofile/pets/editpets.dart';
import 'editprofile/photos/editphotos.dart';
import 'editprofile/recordvideo/recordvideoupdate.dart' show EditVideoScreen;
import 'editprofile/recordvideo/videocontroller.dart';
import 'editprofile/relatioshipgoal/editrelationshipgoal.dart';
import 'editprofilecontroller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final controller = Get.put(EditProfileController());
  bool _showMore = false;
  bool _showGenderDropdown = false;

  final List<String> genderOptions = ['Male', 'Female', 'Other'];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // ✅ Make sure we pop the settings nested navigator
        Get.back(id: settingsNavId);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Edit Profile', style: AppTheme.textTheme.bodyLarge),
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            // ✅ Pop the nested navigator
            onPressed: () => Get.back(id: settingsNavId),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
            children: [
              _item(context, 'Name', controller.name.value, editable: false),
              _item(context, 'Age', controller.age.value, editable: false),

              // Gender (Dropdown toggler)
              _genderTile(context),
              if (_showGenderDropdown) _genderDropdown(context),

              // Height
              _item(
                context,
                'Height',
                null,
                onTap: () async {
                  final result = await Get.to(
                        () => const EditHeightScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                },
              ),

              // Interested In
              _item(context, 'Interested In', null, onTap: () async {
                final result = await Get.to(
                      () => const EditInterestedInScreen(),
                  id: settingsNavId,
                );
                if (result == true) controller.fetchProfile();
              }),

              // PairUp City
              _item(context, 'Your Pairup City', null, onTap: () async {
                final result = await Get.to(
                      () => const EditPairUpLocationScreen(),
                  id: settingsNavId,
                );
                if (result == true) controller.fetchProfile();
              }),

              // Get to Know Me
              _item(context, 'Get to Know Me', null, onTap: () async {
                final result = await Get.to(
                      () => const EditGetToKnowMeScreen(),
                  id: settingsNavId,
                );
                if (result == true) controller.fetchProfile();
              }),

              // Photos
              _item(context, 'Photos', null, onTap: () async {
                final result = await Get.to(
                      () => const EditUploadPhotosScreen(),
                  id: settingsNavId,
                );
                if (result == true) controller.fetchProfile();
              }),
              _item(context, 'test', null, onTap: () async {
                final result = await Get.to(
                      () => const KidsSetupScreen(),
                  id: settingsNavId,
                );
                if (result == true) controller.fetchProfile();
              }),

              _item(context, 'Social Media', null, onTap: () async {
                final result = await Get.to(
                      () => const SocialCircleUpdateScreen(),
                  id: settingsNavId,
                );
                if (result == true) controller.fetchProfile();
              }),

              if (_showMore) ...[
                _item(context, 'About Me', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditAboutMeScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                _item(context, 'Get to know your habbits', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditHabitsScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                _item(context, 'Bonding Moment', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditBondingMomentsScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                _item(context, 'Relationship Goals', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditRelationshipGoalScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                _item(context, 'Pets', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditPetsScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                _item(context, 'Love Language', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditLoveLanguagesScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                _item(context, 'Attachment Style', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditAttachmentStyleScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                _item(context, 'Video', null, onTap: () async {
                  final result = await Get.to(() => EditVideoScreen(
                    videoQuestionId: 30, // ✅ put your actual question_id from categories.json here
                    existingVideoUrl: controller.profileController.videoUrl.value.isEmpty
                        ? null
                        : controller.profileController.videoUrl.value,
                  ));
                  if (result == true) controller.fetchProfile();
                }),
                _item(context, 'Relocate', null, onTap: () async {
                  final result = await Get.to(
                        () => const EditRelocateLoveScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),

                // New screens
                _item(context, 'Zodiac Sign', null, onTap: () async {
                  final result = await Get.to(
                        () => const ZodiacSignScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),
                _item(context, 'Education', null, onTap: () async {
                  final result = await Get.to(
                        () => const EducationScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),
                _item(context, 'Religion', null, onTap: () async {
                  final result = await Get.to(
                        () => const ReligionScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),
                _item(context, 'Political Views', null, onTap: () async {
                  final result = await Get.to(
                        () => const PoliticalViewsScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),
                _item(context, 'Kids', null, onTap: () async {
                  final result = await Get.to(
                        () => const KidsScreen(),
                    id: settingsNavId,
                  );
                  if (result == true) controller.fetchProfile();
                }),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _showMore = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(
                        "More About Me...",
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _item(
      BuildContext context,
      String title,
      String? value, {
        VoidCallback? onTap,
        bool editable = true,
      }) {
    final showValue = value != null && value.trim().isNotEmpty;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          title: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              if (showValue)
                Expanded(
                  child: Text(
                    value!,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          trailing: editable ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black54) : null,
          onTap: editable ? onTap : null,
        ),
        const Divider(thickness: 0.6, height: 0, color: Colors.black12),
      ],
    );
  }

  Widget _genderTile(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          title: Row(
            children: [
              Text(
                'Gender',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Obx(() {
                  final genderValue = controller.gender.value;
                  return Text(
                    genderValue.isNotEmpty ? genderValue : '',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  );
                }),
              ),
            ],
          ),
          trailing: const Icon(Icons.arrow_drop_down, size: 20),
          onTap: () => setState(() {
            _showGenderDropdown = !_showGenderDropdown;
          }),
        ),
        const Divider(thickness: 0.6, height: 0, color: Colors.black12),
      ],
    );
  }

  Widget _genderDropdown(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Obx(() {
        return DropdownButton<String>(
          isExpanded: true,
          value: controller.gender.value.isEmpty ? null : controller.gender.value,
          underline: const SizedBox(),
          dropdownColor: AppTheme.backgroundColor,
          hint: Text('Select Gender', style: Theme.of(context).textTheme.bodySmall),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
          items: ['Male', 'Female', 'Other'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          onChanged: (newValue) async {
            if (newValue != null) {
              await controller.updateGender(newValue);
              setState(() => _showGenderDropdown = false);
            }
          },
        );
      }),
    );
  }
}
