import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('pt', 'BR')
  ];

  /// Localized message for appTitle.
  ///
  /// In en, this message translates to:
  /// **'Atalaia'**
  String get appTitle;

  /// Localized message for commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Localized message for commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Localized message for commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Localized message for commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Localized message for commonSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get commonSaved;

  /// Localized message for commonLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get commonLinkCopied;

  /// Localized message for commonInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid link'**
  String get commonInvalidLink;

  /// Localized message for settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Localized message for settingsSignInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get settingsSignInToContinue;

  /// Localized message for settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// Localized message for settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Localized message for settingsVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get settingsVerification;

  /// Label for the medical campaign category.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get campaignCategoryMedical;

  /// Label for the emergency campaign category.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get campaignCategoryEmergency;

  /// Label for the social action campaign category.
  ///
  /// In en, this message translates to:
  /// **'Social action'**
  String get campaignCategorySocial;

  /// Label for the church campaign category.
  ///
  /// In en, this message translates to:
  /// **'Church'**
  String get campaignCategoryChurch;

  /// Label for the mission campaign category.
  ///
  /// In en, this message translates to:
  /// **'Mission'**
  String get campaignCategoryMission;

  /// Label for the education campaign category.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get campaignCategoryEducation;

  /// Label for the disaster campaign category.
  ///
  /// In en, this message translates to:
  /// **'Disaster'**
  String get campaignCategoryDisaster;

  /// Label for the community project campaign category.
  ///
  /// In en, this message translates to:
  /// **'Community project'**
  String get campaignCategoryCommunityProject;

  /// Label for a draft campaign status.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get campaignStatusDraft;

  /// Label for an active campaign status.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get campaignStatusActive;

  /// Label for a closed campaign status.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get campaignStatusClosed;

  /// Label for a cancelled campaign status.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get campaignStatusCancelled;

  /// Label for urgent campaigns.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get campaignUrgent;

  /// Label for profiles without verification.
  ///
  /// In en, this message translates to:
  /// **'No verification'**
  String get verificationTypeNone;

  /// Label for the community leader verification type.
  ///
  /// In en, this message translates to:
  /// **'Community leader'**
  String get verificationTypeCommunityLeader;

  /// Label for the church verification type.
  ///
  /// In en, this message translates to:
  /// **'Church'**
  String get verificationTypeChurch;

  /// Label for the organization verification type.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get verificationTypeOrganization;

  /// Label for the moderator verification type.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get verificationTypeModerator;

  /// Label for the admin verification type.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get verificationTypeAdmin;

  /// Localized message for settingsModeration.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get settingsModeration;

  /// Localized message for settingsAds.
  ///
  /// In en, this message translates to:
  /// **'Ads'**
  String get settingsAds;

  /// No description provided for @adsLocationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Location not found'**
  String get adsLocationNotFound;

  /// No description provided for @adsInvalidCreative.
  ///
  /// In en, this message translates to:
  /// **'Invalid creative'**
  String get adsInvalidCreative;

  /// No description provided for @adsPinCreated.
  ///
  /// In en, this message translates to:
  /// **'Pin created'**
  String get adsPinCreated;

  /// No description provided for @adsPinCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create pin'**
  String get adsPinCreateFailed;

  /// No description provided for @adsStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated'**
  String get adsStatusUpdated;

  /// No description provided for @adsStatusUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status'**
  String get adsStatusUpdateFailed;

  /// No description provided for @adsNewAdvertiser.
  ///
  /// In en, this message translates to:
  /// **'New advertiser'**
  String get adsNewAdvertiser;

  /// No description provided for @adsFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adsFieldName;

  /// No description provided for @adsFieldEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get adsFieldEmailOptional;

  /// No description provided for @adsFieldPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get adsFieldPhoneOptional;

  /// No description provided for @adsOnlyModeratorsCanCreate.
  ///
  /// In en, this message translates to:
  /// **'Only moderators/admin can create.'**
  String get adsOnlyModeratorsCanCreate;

  /// No description provided for @adsAdvertiserCreated.
  ///
  /// In en, this message translates to:
  /// **'Advertiser created'**
  String get adsAdvertiserCreated;

  /// No description provided for @adsAdvertiserCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create advertiser'**
  String get adsAdvertiserCreateFailed;

  /// No description provided for @adsNewCampaign.
  ///
  /// In en, this message translates to:
  /// **'New campaign'**
  String get adsNewCampaign;

  /// No description provided for @adsFieldDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get adsFieldDescriptionOptional;

  /// No description provided for @adsFieldObjective.
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get adsFieldObjective;

  /// No description provided for @adsObjectiveTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get adsObjectiveTraffic;

  /// No description provided for @adsObjectiveAwareness.
  ///
  /// In en, this message translates to:
  /// **'Awareness'**
  String get adsObjectiveAwareness;

  /// No description provided for @adsObjectivePromotion.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get adsObjectivePromotion;

  /// No description provided for @adsObjectiveCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get adsObjectiveCommunity;

  /// No description provided for @adsObjectiveEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get adsObjectiveEvent;

  /// No description provided for @adsCampaignCreatedDraft.
  ///
  /// In en, this message translates to:
  /// **'Campaign created (draft)'**
  String get adsCampaignCreatedDraft;

  /// No description provided for @adsCampaignCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create campaign'**
  String get adsCampaignCreateFailed;

  /// No description provided for @adsLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get adsLearnMore;

  /// No description provided for @adsNewCreative.
  ///
  /// In en, this message translates to:
  /// **'New creative'**
  String get adsNewCreative;

  /// No description provided for @adsFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adsFieldType;

  /// No description provided for @adsCreativeTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get adsCreativeTypeText;

  /// No description provided for @adsCreativeTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get adsCreativeTypeImage;

  /// No description provided for @adsCreativeTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get adsCreativeTypeVideo;

  /// No description provided for @adsFieldHeadlineOptional.
  ///
  /// In en, this message translates to:
  /// **'Headline (optional)'**
  String get adsFieldHeadlineOptional;

  /// No description provided for @adsFieldTextOptional.
  ///
  /// In en, this message translates to:
  /// **'Text (optional)'**
  String get adsFieldTextOptional;

  /// No description provided for @adsFieldCtaOptional.
  ///
  /// In en, this message translates to:
  /// **'CTA (optional)'**
  String get adsFieldCtaOptional;

  /// No description provided for @adsFieldTargetUrl.
  ///
  /// In en, this message translates to:
  /// **'Target URL'**
  String get adsFieldTargetUrl;

  /// No description provided for @adsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adsActive;

  /// No description provided for @adsInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adsInactive;

  /// No description provided for @adsCreativeCreated.
  ///
  /// In en, this message translates to:
  /// **'Creative created'**
  String get adsCreativeCreated;

  /// No description provided for @adsCreativeCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create creative'**
  String get adsCreativeCreateFailed;

  /// No description provided for @adsNewTargeting.
  ///
  /// In en, this message translates to:
  /// **'New targeting'**
  String get adsNewTargeting;

  /// No description provided for @adsFieldScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get adsFieldScope;

  /// No description provided for @adsScopeWorld.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get adsScopeWorld;

  /// No description provided for @adsScopeCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get adsScopeCountry;

  /// No description provided for @adsScopeState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get adsScopeState;

  /// No description provided for @adsScopeCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get adsScopeCity;

  /// No description provided for @adsScopeCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get adsScopeCommunity;

  /// No description provided for @adsFieldPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get adsFieldPlacement;

  /// No description provided for @adsPlacementFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get adsPlacementFeed;

  /// No description provided for @adsPlacementMapPin.
  ///
  /// In en, this message translates to:
  /// **'Map pin'**
  String get adsPlacementMapPin;

  /// No description provided for @adsPlacementStorySlot.
  ///
  /// In en, this message translates to:
  /// **'Story slot'**
  String get adsPlacementStorySlot;

  /// No description provided for @adsPlacementCommunityFeed.
  ///
  /// In en, this message translates to:
  /// **'Community feed'**
  String get adsPlacementCommunityFeed;

  /// No description provided for @adsFieldLocationPath.
  ///
  /// In en, this message translates to:
  /// **'Location path'**
  String get adsFieldLocationPath;

  /// No description provided for @adsFieldCommunityId.
  ///
  /// In en, this message translates to:
  /// **'Community ID (uuid)'**
  String get adsFieldCommunityId;

  /// No description provided for @adsFieldPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority (int)'**
  String get adsFieldPriority;

  /// No description provided for @adsInvalidCommunity.
  ///
  /// In en, this message translates to:
  /// **'Invalid community'**
  String get adsInvalidCommunity;

  /// No description provided for @adsEmptyPath.
  ///
  /// In en, this message translates to:
  /// **'Empty path'**
  String get adsEmptyPath;

  /// No description provided for @adsTargetingCreated.
  ///
  /// In en, this message translates to:
  /// **'Targeting created'**
  String get adsTargetingCreated;

  /// No description provided for @adsTargetingCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create targeting'**
  String get adsTargetingCreateFailed;

  /// No description provided for @adsCreateCreativeFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a creative first'**
  String get adsCreateCreativeFirst;

  /// No description provided for @adsNewSponsoredPin.
  ///
  /// In en, this message translates to:
  /// **'New sponsored pin'**
  String get adsNewSponsoredPin;

  /// No description provided for @adsFieldCreative.
  ///
  /// In en, this message translates to:
  /// **'Creative'**
  String get adsFieldCreative;

  /// No description provided for @adsFieldLabelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get adsFieldLabelOptional;

  /// No description provided for @adsSupabaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Supabase unavailable to manage ads.'**
  String get adsSupabaseUnavailable;

  /// No description provided for @adsAdvertisersSection.
  ///
  /// In en, this message translates to:
  /// **'Advertisers'**
  String get adsAdvertisersSection;

  /// No description provided for @adsCampaignsSection.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get adsCampaignsSection;

  /// No description provided for @adsCreativesSection.
  ///
  /// In en, this message translates to:
  /// **'Creatives'**
  String get adsCreativesSection;

  /// No description provided for @adsTargetingSection.
  ///
  /// In en, this message translates to:
  /// **'Targeting'**
  String get adsTargetingSection;

  /// No description provided for @adsSponsoredPinsSection.
  ///
  /// In en, this message translates to:
  /// **'Sponsored pins'**
  String get adsSponsoredPinsSection;

  /// No description provided for @adsMetricsSection.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get adsMetricsSection;

  /// No description provided for @adsNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get adsNew;

  /// No description provided for @adsNoAdvertisers.
  ///
  /// In en, this message translates to:
  /// **'No advertisers'**
  String get adsNoAdvertisers;

  /// No description provided for @adsNoCampaigns.
  ///
  /// In en, this message translates to:
  /// **'No campaigns'**
  String get adsNoCampaigns;

  /// No description provided for @adsNoCreatives.
  ///
  /// In en, this message translates to:
  /// **'No creatives'**
  String get adsNoCreatives;

  /// No description provided for @adsNoTargeting.
  ///
  /// In en, this message translates to:
  /// **'No targeting'**
  String get adsNoTargeting;

  /// No description provided for @adsNoPins.
  ///
  /// In en, this message translates to:
  /// **'No pins'**
  String get adsNoPins;

  /// No description provided for @adsNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get adsNoData;

  /// No description provided for @adsSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get adsSelect;

  /// No description provided for @adsActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get adsActivate;

  /// No description provided for @adsPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get adsPause;

  /// No description provided for @adsComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get adsComplete;

  /// No description provided for @adsPriorityShort.
  ///
  /// In en, this message translates to:
  /// **'prio'**
  String get adsPriorityShort;

  /// No description provided for @adsUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get adsUnknown;

  /// No description provided for @adsImpressions.
  ///
  /// In en, this message translates to:
  /// **'Impressions'**
  String get adsImpressions;

  /// No description provided for @adsClicks.
  ///
  /// In en, this message translates to:
  /// **'Clicks'**
  String get adsClicks;

  /// No description provided for @adsCtr.
  ///
  /// In en, this message translates to:
  /// **'CTR'**
  String get adsCtr;

  /// No description provided for @adsLocationPathExample.
  ///
  /// In en, this message translates to:
  /// **'Ex.: world/sa/br/sp/sao-paulo'**
  String get adsLocationPathExample;

  /// No description provided for @adsPinLabelExample.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Sponsored'**
  String get adsPinLabelExample;

  /// No description provided for @adsAdvertiserNameExample.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Ebenezer Bookstore'**
  String get adsAdvertiserNameExample;

  /// No description provided for @adsAdvertiserEmailExample.
  ///
  /// In en, this message translates to:
  /// **'contact@example.com'**
  String get adsAdvertiserEmailExample;

  /// No description provided for @adsAdvertiserPhoneExample.
  ///
  /// In en, this message translates to:
  /// **'+55…'**
  String get adsAdvertiserPhoneExample;

  /// No description provided for @adsCampaignTitleExample.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Discount Bible'**
  String get adsCampaignTitleExample;

  /// No description provided for @adsCampaignDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Internal context…'**
  String get adsCampaignDescriptionHint;

  /// No description provided for @adsHiddenSnack.
  ///
  /// In en, this message translates to:
  /// **'Ad hidden'**
  String get adsHiddenSnack;

  /// No description provided for @communityMemberActionPromoteToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Promote to admin'**
  String get communityMemberActionPromoteToAdmin;

  /// No description provided for @communityMemberActionDemoteToMember.
  ///
  /// In en, this message translates to:
  /// **'Demote to member'**
  String get communityMemberActionDemoteToMember;

  /// No description provided for @communityMemberActionTransferOwnership.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get communityMemberActionTransferOwnership;

  /// No description provided for @communityMemberPromotedSnack.
  ///
  /// In en, this message translates to:
  /// **'Promoted to admin'**
  String get communityMemberPromotedSnack;

  /// No description provided for @communityMemberDemotedSnack.
  ///
  /// In en, this message translates to:
  /// **'Demoted to member'**
  String get communityMemberDemotedSnack;

  /// No description provided for @communityOwnershipTransferConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership?'**
  String get communityOwnershipTransferConfirmTitle;

  /// No description provided for @communityOwnershipTransferConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The community will be under the control of {name}.'**
  String communityOwnershipTransferConfirmBody(Object name);

  /// No description provided for @communityOwnershipTransferredSnack.
  ///
  /// In en, this message translates to:
  /// **'Ownership transferred'**
  String get communityOwnershipTransferredSnack;

  /// No description provided for @communityRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get communityRequestsEmpty;

  /// No description provided for @communityRequestApproveAction.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get communityRequestApproveAction;

  /// No description provided for @communityRequestRejectAction.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get communityRequestRejectAction;

  /// No description provided for @communityRequestApprovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get communityRequestApprovedSnack;

  /// No description provided for @communityRequestRejectedSnack.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get communityRequestRejectedSnack;

  /// No description provided for @communityRequestsCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get communityRequestsCardTitle;

  /// No description provided for @communityRequestsCardLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading requests…'**
  String get communityRequestsCardLoading;

  /// No description provided for @communityRequestsCardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No requests for now.'**
  String get communityRequestsCardEmpty;

  /// No description provided for @communityRequestsCardNoText.
  ///
  /// In en, this message translates to:
  /// **'(no text)'**
  String get communityRequestsCardNoText;

  /// No description provided for @communityRequestsTriageSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Most recent'**
  String get communityRequestsTriageSortNewest;

  /// No description provided for @communityRequestsTriageSortLeastPrayed.
  ///
  /// In en, this message translates to:
  /// **'Least prayers'**
  String get communityRequestsTriageSortLeastPrayed;

  /// No description provided for @communityRequestsTriageSortMostPrayed.
  ///
  /// In en, this message translates to:
  /// **'Most prayers'**
  String get communityRequestsTriageSortMostPrayed;

  /// No description provided for @communityRequestsTriageSortMostCommented.
  ///
  /// In en, this message translates to:
  /// **'Most comments'**
  String get communityRequestsTriageSortMostCommented;

  /// No description provided for @communityRequestsTriageSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search requests'**
  String get communityRequestsTriageSearchHint;

  /// No description provided for @communityRequestsTriageFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get communityRequestsTriageFilterAll;

  /// No description provided for @communityRequestsTriageFilterReported.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get communityRequestsTriageFilterReported;

  /// No description provided for @communityRequestsTriageFilterHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get communityRequestsTriageFilterHidden;

  /// No description provided for @communityRequestsTriageSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get communityRequestsTriageSortTooltip;

  /// No description provided for @communityRequestsTriageEmptyReported.
  ///
  /// In en, this message translates to:
  /// **'No reports in requests.'**
  String get communityRequestsTriageEmptyReported;

  /// No description provided for @communityRequestsTriageEmptyHidden.
  ///
  /// In en, this message translates to:
  /// **'No hidden requests.'**
  String get communityRequestsTriageEmptyHidden;

  /// No description provided for @communityRequestsTriageEmptyCommunity.
  ///
  /// In en, this message translates to:
  /// **'No requests in this community yet.'**
  String get communityRequestsTriageEmptyCommunity;

  /// No description provided for @communityRequestsTriagePrayerRequestFallback.
  ///
  /// In en, this message translates to:
  /// **'Prayer request'**
  String get communityRequestsTriagePrayerRequestFallback;

  /// No description provided for @communityRequestsTriageHiddenChip.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get communityRequestsTriageHiddenChip;

  /// No description provided for @communityRequestsScreenNewRequestTooltip.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get communityRequestsScreenNewRequestTooltip;

  /// No description provided for @communityRequestsScreenTabMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get communityRequestsScreenTabMap;

  /// No description provided for @communityRequestsScreenTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get communityRequestsScreenTabRequests;

  /// No description provided for @communityRequestsScreenTabRequestsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Requests ({count})'**
  String communityRequestsScreenTabRequestsWithCount(Object count);

  /// No description provided for @communityRequestsScreenTabTriage.
  ///
  /// In en, this message translates to:
  /// **'Triage'**
  String get communityRequestsScreenTabTriage;

  /// No description provided for @verificationStatusVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'You are verified'**
  String get verificationStatusVerifiedTitle;

  /// No description provided for @verificationStatusCanceledTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription canceled'**
  String get verificationStatusCanceledTitle;

  /// No description provided for @verificationStatusVerifiedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your profile has an active badge.'**
  String get verificationStatusVerifiedDescription;

  /// No description provided for @verificationStatusCanceledDescription.
  ///
  /// In en, this message translates to:
  /// **'You can subscribe again to reactivate the badge.'**
  String get verificationStatusCanceledDescription;

  /// No description provided for @verificationStatusStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get verificationStatusStartLabel;

  /// No description provided for @verificationStatusPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get verificationStatusPlanLabel;

  /// No description provided for @verificationStatusManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get verificationStatusManageSubscription;

  /// No description provided for @verificationStatusResubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe again'**
  String get verificationStatusResubscribe;

  /// No description provided for @verificationStatusFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get verificationStatusFaqTitle;

  /// No description provided for @verificationStatusFaqHowItWorksQuestion.
  ///
  /// In en, this message translates to:
  /// **'How does verification work?'**
  String get verificationStatusFaqHowItWorksQuestion;

  /// No description provided for @verificationStatusFaqHowItWorksAnswer.
  ///
  /// In en, this message translates to:
  /// **'Verification is activated after server-side payment confirmation.'**
  String get verificationStatusFaqHowItWorksAnswer;

  /// No description provided for @verificationStatusFaqWhenBadgeQuestion.
  ///
  /// In en, this message translates to:
  /// **'When does the badge appear?'**
  String get verificationStatusFaqWhenBadgeQuestion;

  /// No description provided for @verificationStatusFaqWhenBadgeAnswer.
  ///
  /// In en, this message translates to:
  /// **'As soon as the subscription is active on the server.'**
  String get verificationStatusFaqWhenBadgeAnswer;

  /// No description provided for @verificationStatusFaqCancelQuestion.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel anytime?'**
  String get verificationStatusFaqCancelQuestion;

  /// No description provided for @verificationStatusFaqCancelAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yes, management happens in the store (phase 2).'**
  String get verificationStatusFaqCancelAnswer;

  /// No description provided for @regionPostsEmptyTestimonies.
  ///
  /// In en, this message translates to:
  /// **'There are no testimonies in this region yet'**
  String get regionPostsEmptyTestimonies;

  /// No description provided for @regionPostsEmptyRequests.
  ///
  /// In en, this message translates to:
  /// **'There are no requests in this region yet'**
  String get regionPostsEmptyRequests;

  /// No description provided for @regionPostsCreateTestimony.
  ///
  /// In en, this message translates to:
  /// **'Create testimony'**
  String get regionPostsCreateTestimony;

  /// No description provided for @regionPostsCreateRequest.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get regionPostsCreateRequest;

  /// No description provided for @regionPostsTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests in {location}'**
  String regionPostsTitle(Object location);

  /// No description provided for @regionPostsTitleWithCommunity.
  ///
  /// In en, this message translates to:
  /// **'Requests in {location} • {community}'**
  String regionPostsTitleWithCommunity(Object location, Object community);

  /// No description provided for @regionPostsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get regionPostsFilterAll;

  /// No description provided for @regionPostsFilterRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get regionPostsFilterRequests;

  /// No description provided for @regionPostsFilterTestimonies.
  ///
  /// In en, this message translates to:
  /// **'Testimonies'**
  String get regionPostsFilterTestimonies;

  /// No description provided for @regionNewsTitleShort.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get regionNewsTitleShort;

  /// No description provided for @regionNewsTitle.
  ///
  /// In en, this message translates to:
  /// **'News • {location}'**
  String regionNewsTitle(Object location);

  /// No description provided for @regionNewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'There is no relevant news in this region yet.'**
  String get regionNewsEmpty;

  /// No description provided for @regionPrayersTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Prayers'**
  String get regionPrayersTitleShort;

  /// No description provided for @regionPrayersTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayers • {location}'**
  String regionPrayersTitle(Object location);

  /// No description provided for @regionPrayersEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no prayers registered here yet.'**
  String get regionPrayersEmpty;

  /// No description provided for @regionPrayForThisRegion.
  ///
  /// In en, this message translates to:
  /// **'Pray for this region'**
  String get regionPrayForThisRegion;

  /// No description provided for @regionActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get regionActivityTitle;

  /// No description provided for @regionActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'There is no activity in this region yet.'**
  String get regionActivityEmpty;

  /// No description provided for @prayerSessionActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active session'**
  String get prayerSessionActiveTitle;

  /// No description provided for @prayerSessionActivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Do you want to finish or cancel?'**
  String get prayerSessionActivePrompt;

  /// No description provided for @prayerSessionContinuePraying.
  ///
  /// In en, this message translates to:
  /// **'Keep praying'**
  String get prayerSessionContinuePraying;

  /// No description provided for @prayerSessionCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel session'**
  String get prayerSessionCancelAction;

  /// No description provided for @prayerSessionFinishAction.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get prayerSessionFinishAction;

  /// No description provided for @prayerSessionFinishSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish prayer'**
  String get prayerSessionFinishSheetTitle;

  /// No description provided for @prayerSessionFinishSheetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Do you want to record something about this prayer?'**
  String get prayerSessionFinishSheetPrompt;

  /// No description provided for @prayerSessionRecordTypeRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get prayerSessionRecordTypeRecord;

  /// No description provided for @prayerSessionRecordTypeRevelation.
  ///
  /// In en, this message translates to:
  /// **'Revelation'**
  String get prayerSessionRecordTypeRevelation;

  /// No description provided for @prayerSessionRecordTypeTestimony.
  ///
  /// In en, this message translates to:
  /// **'Testimony'**
  String get prayerSessionRecordTypeTestimony;

  /// No description provided for @prayerSessionRecordTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get prayerSessionRecordTypeOther;

  /// No description provided for @prayerSessionRecordTypeField.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get prayerSessionRecordTypeField;

  /// No description provided for @prayerSessionRecordField.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get prayerSessionRecordField;

  /// No description provided for @prayerSessionRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Write here…'**
  String get prayerSessionRecordHint;

  /// No description provided for @prayerSessionSaveAndFinish.
  ///
  /// In en, this message translates to:
  /// **'Save and finish'**
  String get prayerSessionSaveAndFinish;

  /// No description provided for @prayerSessionFinishWithoutRecord.
  ///
  /// In en, this message translates to:
  /// **'Finish without record'**
  String get prayerSessionFinishWithoutRecord;

  /// No description provided for @prayerSessionPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get prayerSessionPaused;

  /// No description provided for @prayerSessionLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get prayerSessionLive;

  /// No description provided for @prayerSessionIntentHint.
  ///
  /// In en, this message translates to:
  /// **'Pray for this region with intention.'**
  String get prayerSessionIntentHint;

  /// No description provided for @prayerSessionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get prayerSessionResume;

  /// No description provided for @prayerSessionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get prayerSessionPause;

  /// No description provided for @playlistStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a playlist'**
  String get playlistStartTitle;

  /// No description provided for @playlistStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose something to accompany your prayer time.'**
  String get playlistStartSubtitle;

  /// No description provided for @playlistStartSkip.
  ///
  /// In en, this message translates to:
  /// **'Start without playlist'**
  String get playlistStartSkip;

  /// No description provided for @playlistNowPlayingTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist selected'**
  String get playlistNowPlayingTitle;

  /// No description provided for @playlistPlayAction.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playlistPlayAction;

  /// No description provided for @playlistShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get playlistShareAction;

  /// No description provided for @playlistItemTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playlistItemTypeAudio;

  /// No description provided for @playlistItemTypeYoutube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get playlistItemTypeYoutube;

  /// No description provided for @playlistItemTypeSpotify.
  ///
  /// In en, this message translates to:
  /// **'Spotify'**
  String get playlistItemTypeSpotify;

  /// No description provided for @playlistSummary.
  ///
  /// In en, this message translates to:
  /// **'{type} • {count} items'**
  String playlistSummary(String type, int count);

  /// No description provided for @playlistLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist library'**
  String get playlistLibraryTitle;

  /// No description provided for @playlistLibraryAction.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get playlistLibraryAction;

  /// No description provided for @playlistLibraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Create your first one.'**
  String get playlistLibraryEmpty;

  /// No description provided for @playlistLibraryCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create playlist'**
  String get playlistLibraryCreateAction;

  /// No description provided for @playlistLibraryUpdateAction.
  ///
  /// In en, this message translates to:
  /// **'Update playlist'**
  String get playlistLibraryUpdateAction;

  /// No description provided for @playlistLibraryManageItems.
  ///
  /// In en, this message translates to:
  /// **'Manage items'**
  String get playlistLibraryManageItems;

  /// No description provided for @playlistLibrarySaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save in library'**
  String get playlistLibrarySaveAction;

  /// No description provided for @playlistLibraryUnsaveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get playlistLibraryUnsaveAction;

  /// No description provided for @playlistSavedToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Playlist saved to your library'**
  String get playlistSavedToLibrary;

  /// No description provided for @playlistRemovedFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Playlist removed from your library'**
  String get playlistRemovedFromLibrary;

  /// No description provided for @playlistLibraryFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Playlist details'**
  String get playlistLibraryFormTitle;

  /// No description provided for @playlistFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get playlistFieldTitle;

  /// No description provided for @playlistFieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Morning intercession'**
  String get playlistFieldTitleHint;

  /// No description provided for @playlistFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get playlistFieldDescription;

  /// No description provided for @playlistFieldDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What is this playlist for?'**
  String get playlistFieldDescriptionHint;

  /// No description provided for @playlistFieldVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get playlistFieldVisibility;

  /// No description provided for @playlistVisibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get playlistVisibilityPrivate;

  /// No description provided for @playlistVisibilityUnlisted.
  ///
  /// In en, this message translates to:
  /// **'Unlisted'**
  String get playlistVisibilityUnlisted;

  /// No description provided for @playlistVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get playlistVisibilityPublic;

  /// No description provided for @playlistDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this playlist?'**
  String get playlistDeleteConfirmTitle;

  /// No description provided for @playlistDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get playlistDeleteConfirmBody;

  /// No description provided for @playlistDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Playlist deleted'**
  String get playlistDeletedSnack;

  /// No description provided for @playlistEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit playlist'**
  String get playlistEditorTitle;

  /// No description provided for @playlistEditorMissing.
  ///
  /// In en, this message translates to:
  /// **'Playlist unavailable'**
  String get playlistEditorMissing;

  /// No description provided for @playlistItemAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get playlistItemAddTitle;

  /// No description provided for @playlistItemAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get playlistItemAddAction;

  /// No description provided for @playlistItemFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Item title'**
  String get playlistItemFieldTitle;

  /// No description provided for @playlistItemFieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Worship before prayer'**
  String get playlistItemFieldTitleHint;

  /// No description provided for @playlistItemFieldType.
  ///
  /// In en, this message translates to:
  /// **'Item type'**
  String get playlistItemFieldType;

  /// No description provided for @playlistItemFieldUrl.
  ///
  /// In en, this message translates to:
  /// **'Link or media URL'**
  String get playlistItemFieldUrl;

  /// No description provided for @playlistItemFieldUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get playlistItemFieldUrlHint;

  /// No description provided for @playlistItemFieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (seconds)'**
  String get playlistItemFieldDuration;

  /// No description provided for @playlistItemFieldDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get playlistItemFieldDurationHint;

  /// No description provided for @playlistOpenAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get playlistOpenAction;

  /// No description provided for @playlistLibraryTabPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistLibraryTabPlaylists;

  /// No description provided for @playlistLibraryTabSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get playlistLibraryTabSongs;

  /// No description provided for @playlistFieldCoverUrl.
  ///
  /// In en, this message translates to:
  /// **'Cover URL'**
  String get playlistFieldCoverUrl;

  /// No description provided for @playlistFieldCoverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get playlistFieldCoverUrlHint;

  /// No description provided for @playlistSongEmpty.
  ///
  /// In en, this message translates to:
  /// **'No songs yet. Add your first song.'**
  String get playlistSongEmpty;

  /// No description provided for @playlistSongAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add song'**
  String get playlistSongAddAction;

  /// No description provided for @playlistSongFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Song details'**
  String get playlistSongFormTitle;

  /// No description provided for @playlistSongFieldSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle / artist'**
  String get playlistSongFieldSubtitle;

  /// No description provided for @playlistSongFieldSubtitleHint.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Artist, ministry, source'**
  String get playlistSongFieldSubtitleHint;

  /// No description provided for @playlistSongAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlistSongAddToPlaylist;

  /// No description provided for @playlistSongDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this song?'**
  String get playlistSongDeleteConfirmTitle;

  /// No description provided for @playlistSongDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will also remove it from playlists.'**
  String get playlistSongDeleteConfirmBody;

  /// No description provided for @playlistSongDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Song deleted'**
  String get playlistSongDeletedSnack;

  /// No description provided for @playlistSongAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Song added to playlist'**
  String get playlistSongAddedToPlaylist;

  /// No description provided for @playlistSongChoosePlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a playlist'**
  String get playlistSongChoosePlaylistTitle;

  /// No description provided for @playlistSongChoosePlaylistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist first.'**
  String get playlistSongChoosePlaylistEmpty;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @createFlowTitleNewPost.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get createFlowTitleNewPost;

  /// No description provided for @createFlowTitleNewStory.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get createFlowTitleNewStory;

  /// No description provided for @createFlowTitleNewVideo.
  ///
  /// In en, this message translates to:
  /// **'New video'**
  String get createFlowTitleNewVideo;

  /// No description provided for @createFlowSelectVideoSnack.
  ///
  /// In en, this message translates to:
  /// **'Select a video'**
  String get createFlowSelectVideoSnack;

  /// No description provided for @createFlowEmptyFileSnack.
  ///
  /// In en, this message translates to:
  /// **'Empty file'**
  String get createFlowEmptyFileSnack;

  /// No description provided for @createFlowStoryMustBePhotoSnack.
  ///
  /// In en, this message translates to:
  /// **'Story must be a photo'**
  String get createFlowStoryMustBePhotoSnack;

  /// No description provided for @createFlowModePost.
  ///
  /// In en, this message translates to:
  /// **'POST'**
  String get createFlowModePost;

  /// No description provided for @createFlowModeStory.
  ///
  /// In en, this message translates to:
  /// **'STORY'**
  String get createFlowModeStory;

  /// No description provided for @createFlowModeVideo.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get createFlowModeVideo;

  /// No description provided for @createFlowSignInToPost.
  ///
  /// In en, this message translates to:
  /// **'Sign in to post'**
  String get createFlowSignInToPost;

  /// No description provided for @createFlowSectionPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get createFlowSectionPost;

  /// No description provided for @createFlowWriteNow.
  ///
  /// In en, this message translates to:
  /// **'Write now'**
  String get createFlowWriteNow;

  /// No description provided for @createFlowAddMedia.
  ///
  /// In en, this message translates to:
  /// **'Add media'**
  String get createFlowAddMedia;

  /// No description provided for @createFlowPostHelp.
  ///
  /// In en, this message translates to:
  /// **'You can publish text-only or attach media without losing region/community context.'**
  String get createFlowPostHelp;

  /// No description provided for @createFlowSectionStory24h.
  ///
  /// In en, this message translates to:
  /// **'Story (24h)'**
  String get createFlowSectionStory24h;

  /// No description provided for @createFlowOpenGallery.
  ///
  /// In en, this message translates to:
  /// **'Open gallery'**
  String get createFlowOpenGallery;

  /// No description provided for @createFlowStoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Stories expire in 24 hours. Caption text is optional.'**
  String get createFlowStoryHelp;

  /// No description provided for @createFlowSectionVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get createFlowSectionVideo;

  /// No description provided for @createFlowSelectVideo.
  ///
  /// In en, this message translates to:
  /// **'Select video'**
  String get createFlowSelectVideo;

  /// No description provided for @createFlowVideoHelp.
  ///
  /// In en, this message translates to:
  /// **'You choose cover and duration before publishing.'**
  String get createFlowVideoHelp;

  /// No description provided for @shofarIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Shofar Icon'**
  String get shofarIconTitle;

  /// No description provided for @mediaEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit media'**
  String get mediaEditTitle;

  /// No description provided for @mediaEditNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get mediaEditNext;

  /// No description provided for @mediaEditCropSection.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get mediaEditCropSection;

  /// No description provided for @mediaEditRotateAction.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get mediaEditRotateAction;

  /// No description provided for @mediaEditCoverSection.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get mediaEditCoverSection;

  /// No description provided for @composerAddLocation.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get composerAddLocation;

  /// No description provided for @composerLocationGoiania.
  ///
  /// In en, this message translates to:
  /// **'Goiânia, GO'**
  String get composerLocationGoiania;

  /// No description provided for @composerLocationSaoPaulo.
  ///
  /// In en, this message translates to:
  /// **'São Paulo, SP'**
  String get composerLocationSaoPaulo;

  /// No description provided for @composerLocationBrazil.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get composerLocationBrazil;

  /// No description provided for @composerRemoveLocation.
  ///
  /// In en, this message translates to:
  /// **'Remove location'**
  String get composerRemoveLocation;

  /// No description provided for @composerMediaSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get composerMediaSheetTitle;

  /// No description provided for @composerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get composerPhoto;

  /// No description provided for @composerVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get composerVideo;

  /// No description provided for @composerEditPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get composerEditPostTitle;

  /// No description provided for @composerNewRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get composerNewRequestTitle;

  /// No description provided for @composerNewTestimonyTitle.
  ///
  /// In en, this message translates to:
  /// **'New testimony'**
  String get composerNewTestimonyTitle;

  /// No description provided for @composerMediaAction.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get composerMediaAction;

  /// No description provided for @composerRequestHint.
  ///
  /// In en, this message translates to:
  /// **'Write your prayer request…'**
  String get composerRequestHint;

  /// No description provided for @composerTestimonyHint.
  ///
  /// In en, this message translates to:
  /// **'Share your testimony…'**
  String get composerTestimonyHint;

  /// No description provided for @composerAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add tag (e.g.: healing)'**
  String get composerAddTagHint;

  /// No description provided for @composerVisibilityField.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get composerVisibilityField;

  /// No description provided for @composerVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get composerVisibilityPublic;

  /// No description provided for @composerVisibilityFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get composerVisibilityFollowers;

  /// No description provided for @composerVisibilityChurch.
  ///
  /// In en, this message translates to:
  /// **'Church'**
  String get composerVisibilityChurch;

  /// No description provided for @alertDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get alertDetailTitle;

  /// No description provided for @alertNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This alert is not available.'**
  String get alertNotAvailable;

  /// No description provided for @alertFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get alertFollow;

  /// No description provided for @alertFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get alertFollowing;

  /// No description provided for @alertFollowAction.
  ///
  /// In en, this message translates to:
  /// **'Follow alert'**
  String get alertFollowAction;

  /// No description provided for @alertSignInToFollow.
  ///
  /// In en, this message translates to:
  /// **'Sign in to follow'**
  String get alertSignInToFollow;

  /// No description provided for @alertFollowingStartedSnack.
  ///
  /// In en, this message translates to:
  /// **'Following alert'**
  String get alertFollowingStartedSnack;

  /// No description provided for @alertFollowingStoppedSnack.
  ///
  /// In en, this message translates to:
  /// **'Stopped following'**
  String get alertFollowingStoppedSnack;

  /// No description provided for @alertConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {value}'**
  String alertConfidenceLabel(Object value);

  /// No description provided for @alertCommunityVoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Community vote'**
  String get alertCommunityVoteTitle;

  /// No description provided for @alertVoteConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get alertVoteConfirmed;

  /// No description provided for @alertVoteFalse.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get alertVoteFalse;

  /// No description provided for @alertVoteResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get alertVoteResolved;

  /// No description provided for @alertVoteRegisteredSnack.
  ///
  /// In en, this message translates to:
  /// **'Vote recorded'**
  String get alertVoteRegisteredSnack;

  /// No description provided for @alertConfidenceHelp.
  ///
  /// In en, this message translates to:
  /// **'Confidence is calculated from votes (confirmed − false).'**
  String get alertConfidenceHelp;

  /// Localized message for settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// Localized message for settingsLanguageRegion.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get settingsLanguageRegion;

  /// Localized message for settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Localized message for settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Localized message for settingsSectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSectionSupport;

  /// Localized message for settingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHelp;

  /// Localized message for settingsTermsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Terms & privacy'**
  String get settingsTermsPrivacy;

  /// Localized message for settingsSectionActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get settingsSectionActions;

  /// Localized message for settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// Localized message for localeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Language & region'**
  String get localeScreenTitle;

  /// Localized message for localeLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get localeLanguageLabel;

  /// Localized message for localeLanguageDevice.
  ///
  /// In en, this message translates to:
  /// **'Automatic (device)'**
  String get localeLanguageDevice;

  /// Localized message for localeLanguagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get localeLanguagePortuguese;

  /// Localized message for localeLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeLanguageEnglish;

  /// Localized message for localeLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get localeLanguageSpanish;

  /// Localized message for localeCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country (ISO)'**
  String get localeCountryLabel;

  /// Localized message for localeTimezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get localeTimezoneLabel;

  /// Localized message for localeTimezoneDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get localeTimezoneDevice;

  /// Localized message for localeReceiveGlobalContent.
  ///
  /// In en, this message translates to:
  /// **'Receive global content'**
  String get localeReceiveGlobalContent;

  /// Localized message for localeHintCountry.
  ///
  /// In en, this message translates to:
  /// **'e.g. BR, US, ES'**
  String get localeHintCountry;

  /// Localized message for localeHintTimezone.
  ///
  /// In en, this message translates to:
  /// **'e.g. America/Sao_Paulo'**
  String get localeHintTimezone;

  /// Localized message for commonSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get commonSignIn;

  /// Localized message for commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// Localized message for searchTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchTabAll;

  /// Localized message for searchTabPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchTabPeople;

  /// Localized message for searchTabPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get searchTabPosts;

  /// Localized message for searchTabCommunities.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get searchTabCommunities;

  /// Localized message for searchSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get searchSuggestionsTitle;

  /// Localized message for searchMapButton.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get searchMapButton;

  /// Localized message for searchTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get searchTopicsTitle;

  /// Localized message for searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String searchNoResults(Object query);

  /// Localized message for searchSectionPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchSectionPeople;

  /// Localized message for searchSectionPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get searchSectionPosts;

  /// Localized message for searchSectionCommunities.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get searchSectionCommunities;

  /// Localized message for searchHintPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get searchHintPeople;

  /// Localized message for searchHintPosts.
  ///
  /// In en, this message translates to:
  /// **'Search posts'**
  String get searchHintPosts;

  /// Localized message for searchHintCommunities.
  ///
  /// In en, this message translates to:
  /// **'Search communities'**
  String get searchHintCommunities;

  /// Localized message for searchTopicHealing.
  ///
  /// In en, this message translates to:
  /// **'healing'**
  String get searchTopicHealing;

  /// Localized message for searchTopicFamily.
  ///
  /// In en, this message translates to:
  /// **'family'**
  String get searchTopicFamily;

  /// Localized message for searchTopicWork.
  ///
  /// In en, this message translates to:
  /// **'work'**
  String get searchTopicWork;

  /// Localized message for searchTopicAnxiety.
  ///
  /// In en, this message translates to:
  /// **'anxiety'**
  String get searchTopicAnxiety;

  /// Localized message for searchTopicGratitude.
  ///
  /// In en, this message translates to:
  /// **'gratitude'**
  String get searchTopicGratitude;

  /// Localized message for searchTopicFinances.
  ///
  /// In en, this message translates to:
  /// **'finances'**
  String get searchTopicFinances;

  /// Localized message for commonSeeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get commonSeeMore;

  /// Localized message for commonSeeLess.
  ///
  /// In en, this message translates to:
  /// **'See less'**
  String get commonSeeLess;

  /// Localized message for commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get commonComingSoon;

  /// Localized message for commonSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// Localized message for commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Localized message for commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// Localized message for commonNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get commonNoConnection;

  /// Localized message for commonNoPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission'**
  String get commonNoPermission;

  /// Localized message for commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// Localized message for commonClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get commonClearSearch;

  /// Localized message for commonRestrictedAccess.
  ///
  /// In en, this message translates to:
  /// **'Restricted access'**
  String get commonRestrictedAccess;

  /// Localized message for commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// Localized message for commonPhase2.
  ///
  /// In en, this message translates to:
  /// **'Phase 2'**
  String get commonPhase2;

  /// Localized message for commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// Localized message for commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Localized message for commonHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get commonHide;

  /// Localized message for commonUnhide.
  ///
  /// In en, this message translates to:
  /// **'Unhide'**
  String get commonUnhide;

  /// Localized message for commonViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get commonViewDetails;

  /// Localized message for commonIdCopied.
  ///
  /// In en, this message translates to:
  /// **'ID copied'**
  String get commonIdCopied;

  /// Localized message for timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// Localized message for timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeAgoMinutes(int minutes);

  /// Localized message for timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeAgoHours(int hours);

  /// Localized message for timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeAgoDays(int days);

  /// Localized message for authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authErrorInvalidCredentials;

  /// Localized message for authErrorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authErrorLoginFailed;

  /// Localized message for authErrorCreateAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create account'**
  String get authErrorCreateAccountFailed;

  /// Localized message for authErrorAccountCreatedNoSession.
  ///
  /// In en, this message translates to:
  /// **'Account created, but no session'**
  String get authErrorAccountCreatedNoSession;

  /// Localized message for authErrorRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Email rate limit reached. Wait a few minutes and try again.'**
  String get authErrorRateLimit;

  /// Localized message for authErrorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Email already registered'**
  String get authErrorEmailAlreadyRegistered;

  /// Localized message for authErrorUsernameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Username unavailable'**
  String get authErrorUsernameUnavailable;

  /// Localized message for authGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to pray, comment, and participate'**
  String get authGateTitle;

  /// Localized message for authGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To continue, sign in or create an account.'**
  String get authGateSubtitle;

  /// Localized message for authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get authWelcomeTitle;

  /// Localized message for authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Localized message for authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Localized message for authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'I forgot my password'**
  String get authForgotPassword;

  /// Localized message for authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// Localized message for authNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get authNameLabel;

  /// Localized message for authUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'@username'**
  String get authUsernameLabel;

  /// Localized message for authAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept terms'**
  String get authAcceptTerms;

  /// Localized message for authHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account → Sign in'**
  String get authHaveAccountSignIn;

  /// Localized message for authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authNameRequired;

  /// Localized message for authUsernameMin3.
  ///
  /// In en, this message translates to:
  /// **'Minimum 3 characters'**
  String get authUsernameMin3;

  /// Localized message for authUsernameAllowedChars.
  ///
  /// In en, this message translates to:
  /// **'Use only a-z, 0-9, . and _'**
  String get authUsernameAllowedChars;

  /// Localized message for authUsernameNoSpaces.
  ///
  /// In en, this message translates to:
  /// **'No spaces'**
  String get authUsernameNoSpaces;

  /// Localized message for authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get authEmailInvalid;

  /// Localized message for authPasswordMin8.
  ///
  /// In en, this message translates to:
  /// **'Password min 8'**
  String get authPasswordMin8;

  /// Localized message for authWaitSeconds.
  ///
  /// In en, this message translates to:
  /// **'Wait {seconds}s'**
  String authWaitSeconds(int seconds);

  /// Localized message for authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetPasswordTitle;

  /// Localized message for authSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get authSendLink;

  /// Localized message for authResetEmailSentSnack.
  ///
  /// In en, this message translates to:
  /// **'We sent an email…'**
  String get authResetEmailSentSnack;

  /// Localized message for authSupabaseNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Supabase not configured'**
  String get authSupabaseNotConfigured;

  /// Localized message for authConfigureSupabase.
  ///
  /// In en, this message translates to:
  /// **'Configure Supabase'**
  String get authConfigureSupabase;

  /// Localized message for authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// Localized message for authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// Localized message for adsHeadlineExample.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Fast delivery'**
  String get adsHeadlineExample;

  /// Localized message for adsMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get adsMessageHint;

  /// Localized message for adsCtaExample.
  ///
  /// In en, this message translates to:
  /// **'Ex.: Buy now'**
  String get adsCtaExample;

  /// Localized message for adsSponsoredLabel.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get adsSponsoredLabel;

  /// Localized message for adsHideAction.
  ///
  /// In en, this message translates to:
  /// **'Hide ad'**
  String get adsHideAction;

  /// Localized message for privacyScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyScreenTitle;

  /// Localized message for privacyScreenComingSoon.
  ///
  /// In en, this message translates to:
  /// **'More privacy options coming soon.'**
  String get privacyScreenComingSoon;

  /// Localized message for logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of Atalaia?'**
  String get logoutConfirmTitle;

  /// Localized message for supabaseSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Supabase'**
  String get supabaseSetupTitle;

  /// Localized message for supabaseSetupResetLocalConfigSnack.
  ///
  /// In en, this message translates to:
  /// **'Local Supabase config reset. Restart the app.'**
  String get supabaseSetupResetLocalConfigSnack;

  /// Localized message for supabaseSetupMissingUrlKeySnack.
  ///
  /// In en, this message translates to:
  /// **'Enter URL and ANON KEY'**
  String get supabaseSetupMissingUrlKeySnack;

  /// Localized message for supabaseSetupConfiguredSnack.
  ///
  /// In en, this message translates to:
  /// **'Supabase configured'**
  String get supabaseSetupConfiguredSnack;

  /// Localized message for notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// Localized message for notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// Localized message for notificationsMarkedAllReadSnack.
  ///
  /// In en, this message translates to:
  /// **'Marked as read'**
  String get notificationsMarkedAllReadSnack;

  /// Localized message for notificationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notificationsFilterAll;

  /// Localized message for notificationsFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationsFilterUnread;

  /// Localized message for notificationsFilterSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get notificationsFilterSocial;

  /// Localized message for notificationsFilterPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get notificationsFilterPrayer;

  /// Localized message for notificationsFilterAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get notificationsFilterAlerts;

  /// Localized message for notificationsFilterScales.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get notificationsFilterScales;

  /// Localized message for notificationsSignInToSee.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view notifications'**
  String get notificationsSignInToSee;

  /// Localized message for notificationsEmptyUnread.
  ///
  /// In en, this message translates to:
  /// **'You have no unread notifications.'**
  String get notificationsEmptyUnread;

  /// Localized message for notificationsEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'You don’t have any notifications yet.'**
  String get notificationsEmptyAll;

  /// Localized message for notificationsCtaViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get notificationsCtaViewAll;

  /// Localized message for notificationsHiddenSnack.
  ///
  /// In en, this message translates to:
  /// **'Notification hidden'**
  String get notificationsHiddenSnack;

  /// Localized message for notificationsBucketToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsBucketToday;

  /// Localized message for notificationsBucketThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get notificationsBucketThisWeek;

  /// Localized message for notificationsBucketThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get notificationsBucketThisMonth;

  /// Localized message for notificationsBucketEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsBucketEarlier;

  /// Localized message for settingsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// Localized message for settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// Localized message for settingsDeactivateAccount.
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get settingsDeactivateAccount;

  /// Localized message for settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Localized message for communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityTitle;

  /// Localized message for communityNotFound.
  ///
  /// In en, this message translates to:
  /// **'Community not found'**
  String get communityNotFound;

  /// Localized message for communityCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Create post'**
  String get communityCreatePost;

  /// Localized message for communityJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get communityJoin;

  /// Localized message for communityRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get communityRequest;

  /// Localized message for communityRequestEntry.
  ///
  /// In en, this message translates to:
  /// **'Request access'**
  String get communityRequestEntry;

  /// Localized message for communityRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get communityRequestSent;

  /// Localized message for communityJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get communityJoined;

  /// Localized message for communityPrivacyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get communityPrivacyLabel;

  /// Localized message for communityPrivacyOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get communityPrivacyOpen;

  /// Localized message for communityPrivacyClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get communityPrivacyClosed;

  /// Localized message for communityMembersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String communityMembersCount(int count);

  /// Localized message for communityFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Community feed'**
  String get communityFeedTitle;

  /// Localized message for communitySignInToSeeFeed.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view the feed'**
  String get communitySignInToSeeFeed;

  /// Localized message for communityMembersOnlyFeed.
  ///
  /// In en, this message translates to:
  /// **'Only members can view this feed'**
  String get communityMembersOnlyFeed;

  /// Localized message for communityMembersOnlyChat.
  ///
  /// In en, this message translates to:
  /// **'Only members can open the chat'**
  String get communityMembersOnlyChat;

  /// Localized message for communitiesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search communities'**
  String get communitiesSearchHint;

  /// Localized message for communitiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No communities yet.'**
  String get communitiesEmpty;

  /// Localized message for communitiesEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No results\nTry another search.'**
  String get communitiesEmptySearch;

  /// Localized message for communitiesGlobalFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'No filter (Global)'**
  String get communitiesGlobalFilterTitle;

  /// Localized message for communitiesGlobalFilterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows public requests'**
  String get communitiesGlobalFilterSubtitle;

  /// Localized message for communityStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get communityStatusPending;

  /// Localized message for communityStatusMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get communityStatusMember;

  /// Localized message for communityDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get communityDescription;

  /// Localized message for communityRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get communityRules;

  /// Localized message for communityNoRulesYet.
  ///
  /// In en, this message translates to:
  /// **'No rules yet.'**
  String get communityNoRulesYet;

  /// Localized message for communityCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create community'**
  String get communityCreateTitle;

  /// Localized message for communityCreateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get communityCreateNameLabel;

  /// Localized message for communityCreateNameHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: Goiânia Intercessors'**
  String get communityCreateNameHint;

  /// Localized message for communityCreateDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'About the community purpose…'**
  String get communityCreateDescriptionHint;

  /// Localized message for communityCreateLocationPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Location (path)'**
  String get communityCreateLocationPathLabel;

  /// Localized message for communityCreateLocationPathHint.
  ///
  /// In en, this message translates to:
  /// **'world/sa/br/go/goiania'**
  String get communityCreateLocationPathHint;

  /// Localized message for communityCreateImageUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Image (URL)'**
  String get communityCreateImageUrlLabel;

  /// Localized message for communityCreateImageUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get communityCreateImageUrlHint;

  /// Localized message for communityCreateJoinModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get communityCreateJoinModeLabel;

  /// Localized message for communityCreateJoinModePublic.
  ///
  /// In en, this message translates to:
  /// **'Public access'**
  String get communityCreateJoinModePublic;

  /// Localized message for communityCreateJoinModeRequest.
  ///
  /// In en, this message translates to:
  /// **'Approval'**
  String get communityCreateJoinModeRequest;

  /// Localized message for communityCreateJoinModeInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite only'**
  String get communityCreateJoinModeInvite;

  /// Localized message for communityCreateVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get communityCreateVisibilityPublic;

  /// Localized message for communityCreateVisibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get communityCreateVisibilityPrivate;

  /// Localized message for communityCreateVisibilityUnlisted.
  ///
  /// In en, this message translates to:
  /// **'Unlisted'**
  String get communityCreateVisibilityUnlisted;

  /// Localized message for communityCreateTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get communityCreateTypeLabel;

  /// Localized message for communityCreateTypeChurch.
  ///
  /// In en, this message translates to:
  /// **'Church'**
  String get communityCreateTypeChurch;

  /// Localized message for communityCreateTypeMinistry.
  ///
  /// In en, this message translates to:
  /// **'Ministry'**
  String get communityCreateTypeMinistry;

  /// Localized message for communityCreateTypePrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get communityCreateTypePrayer;

  /// Localized message for communityJoinedMessage.
  ///
  /// In en, this message translates to:
  /// **'You joined the community'**
  String get communityJoinedMessage;

  /// Localized message for communityCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get communityCancelRequest;

  /// Localized message for communityRequestCanceled.
  ///
  /// In en, this message translates to:
  /// **'Request canceled'**
  String get communityRequestCanceled;

  /// Localized message for communityMessageAdmin.
  ///
  /// In en, this message translates to:
  /// **'Message admin'**
  String get communityMessageAdmin;

  /// Localized message for communitySignInToMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to send a message'**
  String get communitySignInToMessage;

  /// Localized message for communityAdminUnavailableDemo.
  ///
  /// In en, this message translates to:
  /// **'Admin unavailable (demo)'**
  String get communityAdminUnavailableDemo;

  /// Localized message for communityNoPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts in this community yet.'**
  String get communityNoPostsYet;

  /// Localized message for communitySwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch community'**
  String get communitySwitch;

  /// Localized message for communityLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave community'**
  String get communityLeave;

  /// Localized message for communityFeedSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get communityFeedSectionTitle;

  /// Localized message for feedEmptyPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet.'**
  String get feedEmptyPosts;

  /// Localized message for feedCreatePost.
  ///
  /// In en, this message translates to:
  /// **'Create post'**
  String get feedCreatePost;

  /// Localized message for communityMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get communityMembersTitle;

  /// Localized message for communityMembersOnly.
  ///
  /// In en, this message translates to:
  /// **'Only members can view this list.'**
  String get communityMembersOnly;

  /// Localized message for communityMembersTabMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get communityMembersTabMembers;

  /// Localized message for communityMembersTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests ({count})'**
  String communityMembersTabRequests(int count);

  /// Localized message for communityMembersEmptyDemo.
  ///
  /// In en, this message translates to:
  /// **'No members (demo).'**
  String get communityMembersEmptyDemo;

  /// Notification channel name for prayer schedule reminders.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get notificationChannelPrayerRunsName;

  /// Notification channel description for prayer schedule reminders.
  ///
  /// In en, this message translates to:
  /// **'Schedule reminders'**
  String get notificationChannelPrayerRunsDescription;

  /// Fallback title for prayer schedule items when no custom title is available.
  ///
  /// In en, this message translates to:
  /// **'Prayer schedule'**
  String get prayerRunDefaultTitle;

  /// No description provided for @prayerRunStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get prayerRunStatusCancelled;

  /// No description provided for @prayerRunStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get prayerRunStatusCompleted;

  /// No description provided for @prayerRunStatusMissed.
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get prayerRunStatusMissed;

  /// No description provided for @prayerRunStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get prayerRunStatusInProgress;

  /// No description provided for @prayerRunStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get prayerRunStatusScheduled;

  /// No description provided for @prayerRunDetailsDurationLine.
  ///
  /// In en, this message translates to:
  /// **'Duration: {minutes} min'**
  String prayerRunDetailsDurationLine(int minutes);

  /// No description provided for @prayerRunDetailsCommunityLine.
  ///
  /// In en, this message translates to:
  /// **'Community: {community}'**
  String prayerRunDetailsCommunityLine(String community);

  /// No description provided for @prayerRunDetailsIdLine.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String prayerRunDetailsIdLine(String id);

  /// No description provided for @prayerRunDetailsStartPrayer.
  ///
  /// In en, this message translates to:
  /// **'Start prayer'**
  String get prayerRunDetailsStartPrayer;

  /// Notification title for a prayer schedule reminder with the lead time placeholder.
  ///
  /// In en, this message translates to:
  /// **'Schedule reminder ({leadTime})'**
  String notificationPrayerRunReminderTitle(String leadTime);

  /// Localized message for prayerRunsTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get prayerRunsTitleShort;

  /// Localized message for prayerRunsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer schedules'**
  String get prayerRunsTitle;

  /// Localized message for prayerRunsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize, track and fulfill shifts'**
  String get prayerRunsSubtitle;

  /// Localized message for prayerRunsNew.
  ///
  /// In en, this message translates to:
  /// **'New schedule'**
  String get prayerRunsNew;

  /// No description provided for @prayerRunsCreateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Create schedule'**
  String get prayerRunsCreateSheetTitle;

  /// No description provided for @prayerRunsCreateTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get prayerRunsCreateTitleLabel;

  /// No description provided for @prayerRunsCreateTitleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: Weekly prayer'**
  String get prayerRunsCreateTitleHint;

  /// No description provided for @prayerRunsCreateWeeklyFixedTitle.
  ///
  /// In en, this message translates to:
  /// **'Fixed weekly'**
  String get prayerRunsCreateWeeklyFixedTitle;

  /// No description provided for @prayerRunsCreateWeeklyFixedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically generates the next weekly schedules'**
  String get prayerRunsCreateWeeklyFixedSubtitle;

  /// No description provided for @prayerRunsCreateAssigneeLabel.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get prayerRunsCreateAssigneeLabel;

  /// No description provided for @prayerRunsCreateStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get prayerRunsCreateStartLabel;

  /// No description provided for @prayerRunsCreateDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get prayerRunsCreateDayLabel;

  /// No description provided for @prayerRunsCreateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get prayerRunsCreateTimeLabel;

  /// No description provided for @prayerRunsCreateDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get prayerRunsCreateDurationLabel;

  /// No description provided for @prayerRunsCreateSelectAssignee.
  ///
  /// In en, this message translates to:
  /// **'Select an assignee'**
  String get prayerRunsCreateSelectAssignee;

  /// No description provided for @prayerRunsAgendaTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get prayerRunsAgendaTitle;

  /// No description provided for @prayerRunsAgendaCommunityLine.
  ///
  /// In en, this message translates to:
  /// **'Community: {community}'**
  String prayerRunsAgendaCommunityLine(String community);

  /// No description provided for @prayerRunsSummaryToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get prayerRunsSummaryToday;

  /// No description provided for @prayerRunsSummaryUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get prayerRunsSummaryUpcoming;

  /// No description provided for @prayerRunsSummaryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get prayerRunsSummaryCompleted;

  /// No description provided for @prayerRunsSummaryPrayedTime.
  ///
  /// In en, this message translates to:
  /// **'Prayed time'**
  String get prayerRunsSummaryPrayedTime;

  /// No description provided for @prayerRunsHighlightMyNextShift.
  ///
  /// In en, this message translates to:
  /// **'Your next shift'**
  String get prayerRunsHighlightMyNextShift;

  /// No description provided for @prayerRunsEmptyNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'No schedules yet.'**
  String get prayerRunsEmptyNoSchedules;

  /// No description provided for @prayerRunsSectionRecentHistory.
  ///
  /// In en, this message translates to:
  /// **'Recent history'**
  String get prayerRunsSectionRecentHistory;

  /// No description provided for @prayerRunsMyShiftSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your commitments in this community'**
  String get prayerRunsMyShiftSubtitle;

  /// No description provided for @prayerRunsMyShiftEmptyAssigned.
  ///
  /// In en, this message translates to:
  /// **'No shift assigned to you.'**
  String get prayerRunsMyShiftEmptyAssigned;

  /// No description provided for @prayerRunsSectionUpcomingMyShift.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get prayerRunsSectionUpcomingMyShift;

  /// Localized message for prayerRunsTabSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get prayerRunsTabSchedule;

  /// Localized message for prayerRunsTabMyShift.
  ///
  /// In en, this message translates to:
  /// **'My shift'**
  String get prayerRunsTabMyShift;

  /// Localized message for prayerRunsTabReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get prayerRunsTabReport;

  /// No description provided for @prayerRunsReportEmpty.
  ///
  /// In en, this message translates to:
  /// **'No report data.'**
  String get prayerRunsReportEmpty;

  /// No description provided for @prayerRunsReportDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get prayerRunsReportDashboardTitle;

  /// No description provided for @prayerRunsReportPrayedTime.
  ///
  /// In en, this message translates to:
  /// **'Prayed time'**
  String get prayerRunsReportPrayedTime;

  /// No description provided for @prayerRunsReportSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get prayerRunsReportSessions;

  /// No description provided for @prayerRunsReportCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get prayerRunsReportCompleted;

  /// No description provided for @prayerRunsReportMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get prayerRunsReportMissed;

  /// No description provided for @prayerRunsReportByMember.
  ///
  /// In en, this message translates to:
  /// **'By member'**
  String get prayerRunsReportByMember;

  /// No description provided for @prayerRunsReportEmptyByMember.
  ///
  /// In en, this message translates to:
  /// **'No data by member.'**
  String get prayerRunsReportEmptyByMember;

  /// No description provided for @prayerRunsReportMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Time: {minutes} min • Sessions: {sessions} • Completed: {completed} • Missed: {missed}'**
  String prayerRunsReportMemberSubtitle(int minutes, int sessions, int completed, int missed);

  /// No description provided for @prayerRunsReportByOccurrence.
  ///
  /// In en, this message translates to:
  /// **'By occurrence'**
  String get prayerRunsReportByOccurrence;

  /// No description provided for @prayerRunsReportEmptyByOccurrence.
  ///
  /// In en, this message translates to:
  /// **'No occurrences in this period.'**
  String get prayerRunsReportEmptyByOccurrence;

  /// No description provided for @prayerRunsReportActualEmpty.
  ///
  /// In en, this message translates to:
  /// **'Actual: —'**
  String get prayerRunsReportActualEmpty;

  /// No description provided for @prayerRunsReportActualRange.
  ///
  /// In en, this message translates to:
  /// **'Actual: {start} – {end}'**
  String prayerRunsReportActualRange(String start, String end);

  /// No description provided for @prayerRunsReportStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get prayerRunsReportStatusCompleted;

  /// No description provided for @prayerRunsReportStatusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get prayerRunsReportStatusMissed;

  /// No description provided for @prayerRunsReportStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get prayerRunsReportStatusCancelled;

  /// No description provided for @prayerRunsReportStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get prayerRunsReportStatusScheduled;

  /// No description provided for @prayerRunsReportActualDurationPart.
  ///
  /// In en, this message translates to:
  /// **' • Actual: {minutes} min'**
  String prayerRunsReportActualDurationPart(int minutes);

  /// No description provided for @prayerRunsReportStatusLine.
  ///
  /// In en, this message translates to:
  /// **'Status: {status} • Planned: {planned} min{actualPart}'**
  String prayerRunsReportStatusLine(String status, int planned, String actualPart);

  /// No description provided for @prayerRunsReportNoteLine.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String prayerRunsReportNoteLine(String note);

  /// No description provided for @prayerRunsReportAssigneeLine.
  ///
  /// In en, this message translates to:
  /// **'Assignee: {name}'**
  String prayerRunsReportAssigneeLine(String name);

  /// Localized message for prayerRunsMembersOnly.
  ///
  /// In en, this message translates to:
  /// **'Only members can view.'**
  String get prayerRunsMembersOnly;

  /// Localized message for communityEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get communityEventsTitle;

  /// Localized message for communityEventsTitleWithCommunity.
  ///
  /// In en, this message translates to:
  /// **'{community} • Events'**
  String communityEventsTitleWithCommunity(String community);

  /// Localized message for communityEventsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get communityEventsEmpty;

  /// Localized message for communityMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Community map'**
  String get communityMapTitle;

  /// Localized message for communityEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit community'**
  String get communityEditTitle;

  /// Localized message for communityEditNoPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to edit this community'**
  String get communityEditNoPermission;

  /// Localized message for communityEventCreateSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get communityEventCreateSheetTitle;

  /// Localized message for communityEventCreateTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get communityEventCreateTitleLabel;

  /// Localized message for communityEventCreateTitleHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: Prayer vigil'**
  String get communityEventCreateTitleHint;

  /// Localized message for communityEventCreateDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get communityEventCreateDescriptionLabel;

  /// Localized message for communityEventCreateDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Event details…'**
  String get communityEventCreateDescriptionHint;

  /// Localized message for communityEventCreateLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get communityEventCreateLocationLabel;

  /// Localized message for communityEventCreateLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Address / link'**
  String get communityEventCreateLocationHint;

  /// Localized message for communityEventCreateStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get communityEventCreateStartLabel;

  /// Localized message for communityEventCreateEndOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'End (optional)'**
  String get communityEventCreateEndOptionalLabel;

  /// Localized message for communityEventCreateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get communityEventCreateSubmit;

  /// Localized message for communityEditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit details and rules'**
  String get communityEditSubtitle;

  /// Localized message for communityEditChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get communityEditChangePhoto;

  /// Localized message for communityEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get communityEditNameHint;

  /// Localized message for communityEditDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get communityEditDescriptionHint;

  /// Localized message for communityEditRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Rules (one per line)'**
  String get communityEditRulesHint;

  /// Localized message for commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Localized message for alertUrgency.
  ///
  /// In en, this message translates to:
  /// **'Urgency: {label}'**
  String alertUrgency(String label);

  /// Localized message for alertExpiresAt.
  ///
  /// In en, this message translates to:
  /// **'expires {time}'**
  String alertExpiresAt(String time);

  /// Localized message for alertUrgencyLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get alertUrgencyLow;

  /// Localized message for alertUrgencyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get alertUrgencyMedium;

  /// Localized message for alertUrgencyHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get alertUrgencyHigh;

  /// Localized message for alertUrgencyCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get alertUrgencyCritical;

  /// Localized message for alertCategoryPrayer.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get alertCategoryPrayer;

  /// Localized message for alertCategorySecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get alertCategorySecurity;

  /// Localized message for alertCategoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get alertCategoryHealth;

  /// Localized message for alertCategoryMissingPerson.
  ///
  /// In en, this message translates to:
  /// **'Missing person'**
  String get alertCategoryMissingPerson;

  /// Localized message for alertCategorySocialNeed.
  ///
  /// In en, this message translates to:
  /// **'Social need'**
  String get alertCategorySocialNeed;

  /// Localized message for alertCategoryTraffic.
  ///
  /// In en, this message translates to:
  /// **'Traffic'**
  String get alertCategoryTraffic;

  /// Localized message for alertCategoryPublicUtility.
  ///
  /// In en, this message translates to:
  /// **'Public utility'**
  String get alertCategoryPublicUtility;

  /// Localized message for alertCategoryEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get alertCategoryEmergency;

  /// Localized message for notificationActorAndMore.
  ///
  /// In en, this message translates to:
  /// **'@{username} and {count} more'**
  String notificationActorAndMore(String username, int count);

  /// Localized message for notificationFollowBack.
  ///
  /// In en, this message translates to:
  /// **'Follow back'**
  String get notificationFollowBack;

  /// Localized message for notificationCtaReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get notificationCtaReply;

  /// Localized message for notificationCtaView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get notificationCtaView;

  /// Localized message for notificationCtaOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get notificationCtaOpen;

  /// Localized message for notificationFollowOne.
  ///
  /// In en, this message translates to:
  /// **'started following you'**
  String get notificationFollowOne;

  /// Localized message for notificationFollowMany.
  ///
  /// In en, this message translates to:
  /// **'started following you'**
  String get notificationFollowMany;

  /// Localized message for notificationReactionOne.
  ///
  /// In en, this message translates to:
  /// **'reacted to your post'**
  String get notificationReactionOne;

  /// Localized message for notificationReactionMany.
  ///
  /// In en, this message translates to:
  /// **'reacted to your post'**
  String get notificationReactionMany;

  /// Localized message for notificationCommentOneNoBody.
  ///
  /// In en, this message translates to:
  /// **'commented on your post'**
  String get notificationCommentOneNoBody;

  /// Localized message for notificationCommentManyNoBody.
  ///
  /// In en, this message translates to:
  /// **'commented on your post'**
  String get notificationCommentManyNoBody;

  /// Localized message for notificationCommentOneWithBody.
  ///
  /// In en, this message translates to:
  /// **'commented: “{body}”'**
  String notificationCommentOneWithBody(String body);

  /// Localized message for notificationCommentManyWithBody.
  ///
  /// In en, this message translates to:
  /// **'commented: “{body}”'**
  String notificationCommentManyWithBody(String body);

  /// Localized message for notificationPrayedRequestOne.
  ///
  /// In en, this message translates to:
  /// **'prayed for your request'**
  String get notificationPrayedRequestOne;

  /// Localized message for notificationPrayedRequestMany.
  ///
  /// In en, this message translates to:
  /// **'prayed for your request'**
  String get notificationPrayedRequestMany;

  /// Localized message for notificationPrayedPostOne.
  ///
  /// In en, this message translates to:
  /// **'prayed for your post'**
  String get notificationPrayedPostOne;

  /// Localized message for notificationPrayedPostMany.
  ///
  /// In en, this message translates to:
  /// **'prayed for your post'**
  String get notificationPrayedPostMany;

  /// Localized message for notificationPostNewOneNoBody.
  ///
  /// In en, this message translates to:
  /// **'posted a new post'**
  String get notificationPostNewOneNoBody;

  /// Localized message for notificationPostNewManyNoBody.
  ///
  /// In en, this message translates to:
  /// **'posted a new post'**
  String get notificationPostNewManyNoBody;

  /// Localized message for notificationPostNewOneWithBody.
  ///
  /// In en, this message translates to:
  /// **'posted a new post: “{body}”'**
  String notificationPostNewOneWithBody(String body);

  /// Localized message for notificationPostNewManyWithBody.
  ///
  /// In en, this message translates to:
  /// **'posted a new post: “{body}”'**
  String notificationPostNewManyWithBody(String body);

  /// Localized message for notificationStoryNew.
  ///
  /// In en, this message translates to:
  /// **'posted a new story'**
  String get notificationStoryNew;

  /// Localized message for notificationAlertNewOneNoBody.
  ///
  /// In en, this message translates to:
  /// **'sent an alert'**
  String get notificationAlertNewOneNoBody;

  /// Localized message for notificationAlertNewManyNoBody.
  ///
  /// In en, this message translates to:
  /// **'sent an alert'**
  String get notificationAlertNewManyNoBody;

  /// Localized message for notificationAlertNewOneWithBody.
  ///
  /// In en, this message translates to:
  /// **'sent an alert: “{body}”'**
  String notificationAlertNewOneWithBody(String body);

  /// Localized message for notificationAlertNewManyWithBody.
  ///
  /// In en, this message translates to:
  /// **'sent an alert: “{body}”'**
  String notificationAlertNewManyWithBody(String body);

  /// Localized message for notificationPrayerRequestOneNoBody.
  ///
  /// In en, this message translates to:
  /// **'posted a prayer request'**
  String get notificationPrayerRequestOneNoBody;

  /// Localized message for notificationPrayerRequestManyNoBody.
  ///
  /// In en, this message translates to:
  /// **'posted a prayer request'**
  String get notificationPrayerRequestManyNoBody;

  /// Localized message for notificationPrayerRequestOneWithBody.
  ///
  /// In en, this message translates to:
  /// **'posted a prayer request: “{body}”'**
  String notificationPrayerRequestOneWithBody(String body);

  /// Localized message for notificationPrayerRequestManyWithBody.
  ///
  /// In en, this message translates to:
  /// **'posted a prayer request: “{body}”'**
  String notificationPrayerRequestManyWithBody(String body);

  /// Localized message for notificationScaleReminder24hNoBody.
  ///
  /// In en, this message translates to:
  /// **'has a schedule in 24h'**
  String get notificationScaleReminder24hNoBody;

  /// Localized message for notificationScaleReminder24hWithBody.
  ///
  /// In en, this message translates to:
  /// **'schedule reminder (24h): “{body}”'**
  String notificationScaleReminder24hWithBody(String body);

  /// Localized message for notificationScaleReminder1hNoBody.
  ///
  /// In en, this message translates to:
  /// **'has a schedule in 1h'**
  String get notificationScaleReminder1hNoBody;

  /// Localized message for notificationScaleReminder1hWithBody.
  ///
  /// In en, this message translates to:
  /// **'schedule reminder (1h): “{body}”'**
  String notificationScaleReminder1hWithBody(String body);

  /// Localized message for notificationScaleReminder5mNoBody.
  ///
  /// In en, this message translates to:
  /// **'has a schedule in 5 min'**
  String get notificationScaleReminder5mNoBody;

  /// Localized message for notificationScaleReminder5mWithBody.
  ///
  /// In en, this message translates to:
  /// **'schedule reminder (5 min): “{body}”'**
  String notificationScaleReminder5mWithBody(String body);

  /// Localized message for commonPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get commonPublish;

  /// Localized message for commonPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get commonPublished;

  /// Localized message for commonSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get commonSent;

  /// Localized message for commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// Localized message for commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// Localized message for commonCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get commonCamera;

  /// Localized message for commonGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get commonGallery;

  /// Localized message for commonUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get commonUserFallback;

  /// Localized message for navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Localized message for navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Localized message for navDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get navDirect;

  /// Localized message for navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Localized message for mainTitleMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mainTitleMap;

  /// Localized message for mainTitleMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get mainTitleMessages;

  /// Localized message for mainTitleProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get mainTitleProfile;

  /// Localized message for mainTitleCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get mainTitleCommunity;

  /// Localized message for mainLeadingFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get mainLeadingFeed;

  /// Localized message for mainLeadingNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get mainLeadingNewMessage;

  /// Localized message for mainLeadingMoment.
  ///
  /// In en, this message translates to:
  /// **'Moment'**
  String get mainLeadingMoment;

  /// Localized message for mainLeadingCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get mainLeadingCreate;

  /// Localized message for mainActionChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get mainActionChat;

  /// Localized message for mainActionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get mainActionNotifications;

  /// Localized message for mainActionCommunities.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get mainActionCommunities;

  /// Localized message for mainActionRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get mainActionRequests;

  /// Localized message for mainActionMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get mainActionMenu;

  /// Localized message for directSignInToOpen.
  ///
  /// In en, this message translates to:
  /// **'Sign in to open Direct'**
  String get directSignInToOpen;

  /// Localized message for directSignInToSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to send messages'**
  String get directSignInToSendMessage;

  /// Localized message for directEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your Direct is still empty.\nSend a message to get started.'**
  String get directEmpty;

  /// Localized message for directEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No conversations found.\nTry another search.'**
  String get directEmptySearch;

  /// Localized message for directSearchPeopleHint.
  ///
  /// In en, this message translates to:
  /// **'Search people'**
  String get directSearchPeopleHint;

  /// Localized message for directEmptyPeopleSearch.
  ///
  /// In en, this message translates to:
  /// **'No results for this search.'**
  String get directEmptyPeopleSearch;

  /// Localized message for directCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get directCamera;

  /// Localized message for directCameraComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Camera (coming soon)'**
  String get directCameraComingSoon;

  /// Localized message for chatSignInToChat.
  ///
  /// In en, this message translates to:
  /// **'Sign in to chat'**
  String get chatSignInToChat;

  /// Localized message for directGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get directGroupLabel;

  /// Localized message for directDeleteConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation?'**
  String get directDeleteConversationTitle;

  /// Localized message for directDeleteConversationMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the conversation from your inbox (demo).'**
  String get directDeleteConversationMessage;

  /// Localized message for storiesTitleMoments.
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get storiesTitleMoments;

  /// Localized message for storiesYourStory.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get storiesYourStory;

  /// Localized message for storiesUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get storiesUserFallback;

  /// Localized message for storiesNoStoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No stories yet'**
  String get storiesNoStoriesYet;

  /// Localized message for storiesShareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get storiesShareSheetTitle;

  /// Localized message for storiesCaptionHintOptional.
  ///
  /// In en, this message translates to:
  /// **'Caption (optional)…'**
  String get storiesCaptionHintOptional;

  /// Localized message for storiesShareIn.
  ///
  /// In en, this message translates to:
  /// **'Share in'**
  String get storiesShareIn;

  /// Localized message for storiesShareTargetMyStory.
  ///
  /// In en, this message translates to:
  /// **'My story'**
  String get storiesShareTargetMyStory;

  /// Localized message for storiesShareTargetCurrentRegion.
  ///
  /// In en, this message translates to:
  /// **'Current region'**
  String get storiesShareTargetCurrentRegion;

  /// Localized message for storiesPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get storiesPublish;

  /// Localized message for storiesPublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing…'**
  String get storiesPublishing;

  /// Localized message for storiesPublished.
  ///
  /// In en, this message translates to:
  /// **'Story published'**
  String get storiesPublished;

  /// Localized message for storiesPublishedInPlace.
  ///
  /// In en, this message translates to:
  /// **'Story published in {place}'**
  String storiesPublishedInPlace(String place);

  /// Localized message for storiesPublishedWithCommunity.
  ///
  /// In en, this message translates to:
  /// **'Story published • {community}'**
  String storiesPublishedWithCommunity(String community);

  /// Localized message for storiesPublishedWithCommunityAndPlace.
  ///
  /// In en, this message translates to:
  /// **'Story published • {community} • {place}'**
  String storiesPublishedWithCommunityAndPlace(String community, String place);

  /// Localized message for storiesPlaceFallbackCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get storiesPlaceFallbackCity;

  /// Localized message for postTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postTitle;

  /// Localized message for postUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This post isn\'t available.'**
  String get postUnavailable;

  /// Localized message for postView.
  ///
  /// In en, this message translates to:
  /// **'View post'**
  String get postView;

  /// Localized message for profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Localized message for profileSignInToView.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your profile'**
  String get profileSignInToView;

  /// Localized message for profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Profile not found'**
  String get profileNotFound;

  /// Localized message for profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Profile unavailable'**
  String get profileUnavailable;

  /// Localized message for profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditProfile;

  /// Localized message for profileEditUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileEditUpdated;

  /// Localized message for profileEditChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get profileEditChangePhoto;

  /// Localized message for profileEditNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileEditNameLabel;

  /// Localized message for profileEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileEditNameHint;

  /// Localized message for profileEditBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileEditBioLabel;

  /// Localized message for profileEditBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell a bit about yourself…'**
  String get profileEditBioHint;

  /// Localized message for profileEditChurchOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Church (optional)'**
  String get profileEditChurchOptionalLabel;

  /// Localized message for profileEditChurchHint.
  ///
  /// In en, this message translates to:
  /// **'E.g.: Assembly of God'**
  String get profileEditChurchHint;

  /// Localized message for profileFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollow;

  /// Localized message for profileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// Localized message for profileUnfollowed.
  ///
  /// In en, this message translates to:
  /// **'Unfollowed'**
  String get profileUnfollowed;

  /// Localized message for profileMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get profileMessage;

  /// Localized message for profilePosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profilePosts;

  /// Localized message for profileFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileFollowers;

  /// Localized message for profileFollowingLabel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowingLabel;

  /// Localized message for profilePrayers.
  ///
  /// In en, this message translates to:
  /// **'Prayers'**
  String get profilePrayers;

  /// Localized message for profilePrayersReceived.
  ///
  /// In en, this message translates to:
  /// **'Prayers received'**
  String get profilePrayersReceived;

  /// Localized message for profileCopyProfileLink.
  ///
  /// In en, this message translates to:
  /// **'Copy profile link'**
  String get profileCopyProfileLink;

  /// Localized message for profileReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get profileReport;

  /// Localized message for profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// Localized message for profileVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get profileVerification;

  /// Localized message for profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// Localized message for profileFollowToggleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get profileFollowToggleSignIn;

  /// Localized message for profileSnackFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileSnackFollowing;

  /// Localized message for profileSnackUnfollowed.
  ///
  /// In en, this message translates to:
  /// **'Unfollowed'**
  String get profileSnackUnfollowed;

  /// Localized message for followersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get followersSearchHint;

  /// Localized message for followersEmptyFollowers.
  ///
  /// In en, this message translates to:
  /// **'No followers yet.'**
  String get followersEmptyFollowers;

  /// Localized message for followersEmptyFollowing.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet.'**
  String get followersEmptyFollowing;

  /// Localized message for postActionReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get postActionReport;

  /// Localized message for postActionCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get postActionCopyLink;

  /// Localized message for postActionHidePost.
  ///
  /// In en, this message translates to:
  /// **'Hide post'**
  String get postActionHidePost;

  /// Localized message for postActionUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get postActionUnfollow;

  /// Localized message for postActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get postActionEdit;

  /// Localized message for postActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get postActionDelete;

  /// Localized message for shareSheetExternalShare.
  ///
  /// In en, this message translates to:
  /// **'Share externally'**
  String get shareSheetExternalShare;

  /// Localized message for shareSheetSendDirect.
  ///
  /// In en, this message translates to:
  /// **'Send via Direct'**
  String get shareSheetSendDirect;

  /// Localized message for shareSheetSharedPost.
  ///
  /// In en, this message translates to:
  /// **'Shared a post'**
  String get shareSheetSharedPost;

  /// Localized message for postReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get postReportSubmit;

  /// Localized message for postReportExplainHint.
  ///
  /// In en, this message translates to:
  /// **'Explain…'**
  String get postReportExplainHint;

  /// Localized message for postReportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get postReportReasonSpam;

  /// Localized message for postReportReasonInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get postReportReasonInappropriate;

  /// Localized message for postReportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment / threats'**
  String get postReportReasonHarassment;

  /// Localized message for postReportReasonMisleading.
  ///
  /// In en, this message translates to:
  /// **'False / misleading'**
  String get postReportReasonMisleading;

  /// Localized message for postReportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get postReportReasonOther;

  /// Localized message for postSnackReportSent.
  ///
  /// In en, this message translates to:
  /// **'Report sent'**
  String get postSnackReportSent;

  /// Localized message for postSnackPostHidden.
  ///
  /// In en, this message translates to:
  /// **'Post hidden'**
  String get postSnackPostHidden;

  /// Localized message for postSnackPostUnhidden.
  ///
  /// In en, this message translates to:
  /// **'Post unhidden'**
  String get postSnackPostUnhidden;

  /// Localized message for postSnackUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get postSnackUndo;

  /// Localized message for postDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get postDeleteConfirmTitle;

  /// Localized message for postDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This action can\'t be undone.'**
  String get postDeleteConfirmMessage;

  /// Localized message for postDeleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get postDeleteConfirmLabel;

  /// Localized message for postSnackPostDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postSnackPostDeleted;

  /// Localized message for postSignInToComment.
  ///
  /// In en, this message translates to:
  /// **'Sign in to comment'**
  String get postSignInToComment;

  /// Localized message for postSaveFailedCheckSupabase.
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Check the Supabase connection.'**
  String get postSaveFailedCheckSupabase;

  /// Localized message for postSaveFailedWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {message}'**
  String postSaveFailedWithMessage(String message);

  /// Localized message for postPublishFailedCheckSupabase.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish. Check the Supabase connection.'**
  String get postPublishFailedCheckSupabase;

  /// Localized message for postPublishFailedWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish: {message}'**
  String postPublishFailedWithMessage(String message);

  /// Localized message for ctaSignInToCreate.
  ///
  /// In en, this message translates to:
  /// **'Sign in to create'**
  String get ctaSignInToCreate;

  /// Localized message for alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// Localized message for alertsTitleWithLocation.
  ///
  /// In en, this message translates to:
  /// **'Alerts • {location}'**
  String alertsTitleWithLocation(String location);

  /// Localized message for alertsTitleWithLocationAndCommunity.
  ///
  /// In en, this message translates to:
  /// **'Alerts • {location} • {community}'**
  String alertsTitleWithLocationAndCommunity(String location, String community);

  /// Localized message for alertsCreateAlert.
  ///
  /// In en, this message translates to:
  /// **'Create alert'**
  String get alertsCreateAlert;

  /// Localized message for alertsNoAlertsInRegion.
  ///
  /// In en, this message translates to:
  /// **'There are no alerts in this region yet.'**
  String get alertsNoAlertsInRegion;

  /// Localized message for regionIdentifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t identify the region.'**
  String get regionIdentifyFailed;

  /// Localized message for eventLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this event.'**
  String get eventLoadFailed;

  /// Localized message for paymentStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start payment'**
  String get paymentStartFailed;

  /// Localized message for prayerSessionStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the prayer session'**
  String get prayerSessionStartFailed;

  /// Localized message for likeRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t register the like.'**
  String get likeRegisterFailed;

  /// Localized message for prayerRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t register the prayer.'**
  String get prayerRegisterFailed;

  /// Localized message for participationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your participation.'**
  String get participationUpdateFailed;

  /// Localized message for prayerSessionStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting session…'**
  String get prayerSessionStarting;

  /// Localized message for prayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pray'**
  String get prayerTitle;

  /// Localized message for postPrayAction.
  ///
  /// In en, this message translates to:
  /// **'I prayed'**
  String get postPrayAction;

  /// Localized message for postLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get postLike;

  /// Localized message for postComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get postComment;

  /// Localized message for postShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get postShare;

  /// Localized message for postMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get postMore;

  /// Localized message for commentAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get commentAddLabel;

  /// Localized message for commentNoCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get commentNoCommentsYet;

  /// Localized message for commentBeFirst.
  ///
  /// In en, this message translates to:
  /// **'Be the first to comment.'**
  String get commentBeFirst;

  /// Localized message for prayerStart.
  ///
  /// In en, this message translates to:
  /// **'Start prayer'**
  String get prayerStart;

  /// Localized message for prayerRegisteredSnack.
  ///
  /// In en, this message translates to:
  /// **'Prayer registered'**
  String get prayerRegisteredSnack;

  /// Localized message for prayerRequestActionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open request'**
  String get prayerRequestActionOpen;

  /// Localized message for prayerRequestActionPray.
  ///
  /// In en, this message translates to:
  /// **'Pray'**
  String get prayerRequestActionPray;

  /// Localized message for prayerRequestCopyId.
  ///
  /// In en, this message translates to:
  /// **'Copy request ID'**
  String get prayerRequestCopyId;

  /// Localized message for reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// Localized message for reportsViewCount.
  ///
  /// In en, this message translates to:
  /// **'View reports ({count})'**
  String reportsViewCount(int count);

  /// Localized message for reportsNoReason.
  ///
  /// In en, this message translates to:
  /// **'No reason'**
  String get reportsNoReason;

  /// Localized message for reportsStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get reportsStatusOpen;

  /// Localized message for reportsStatusReviewing.
  ///
  /// In en, this message translates to:
  /// **'reviewing'**
  String get reportsStatusReviewing;

  /// Localized message for reportsStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'resolved'**
  String get reportsStatusResolved;

  /// Localized message for reportsStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'dismissed'**
  String get reportsStatusDismissed;

  /// Localized message for reportsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {label}'**
  String reportsStatus(String label);

  /// Localized message for commentDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete comment?'**
  String get commentDeleteConfirmTitle;

  /// Localized message for commentDeletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get commentDeletedSnack;

  /// Localized message for messageStatusSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get messageStatusSending;

  /// Localized message for messageStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get messageStatusFailed;

  /// Localized message for chatDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get chatDetailsAction;

  /// Localized message for chatDetailsUiPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Details (UI)'**
  String get chatDetailsUiPlaceholder;

  /// Localized message for chatAttachmentImageAttached.
  ///
  /// In en, this message translates to:
  /// **'Image attached'**
  String get chatAttachmentImageAttached;

  /// Localized message for chatAttachmentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get chatAttachmentRemove;

  /// Localized message for chatAttachmentAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attach photo'**
  String get chatAttachmentAddPhoto;

  /// Localized message for chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get chatComposerHint;

  /// Localized message for chatSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatSendMessage;

  /// Localized message for chatOpenLinkUi.
  ///
  /// In en, this message translates to:
  /// **'Open link (UI): {url}'**
  String chatOpenLinkUi(Object url);

  /// Localized message for uploadSupabaseOnly.
  ///
  /// In en, this message translates to:
  /// **'Upload available only with Supabase configured'**
  String get uploadSupabaseOnly;

  /// Localized message for uploadFailedWithCode.
  ///
  /// In en, this message translates to:
  /// **'Upload failed{code}: {message}'**
  String uploadFailedWithCode(String code, String message);

  /// Localized message for mediaSelectedReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the selected media'**
  String get mediaSelectedReadFailed;

  /// Localized message for mediaSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t upload the media'**
  String get mediaSendFailed;

  /// Localized message for photoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get photoUpdated;

  /// Localized message for composerFileExtensionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'File extension not supported'**
  String get composerFileExtensionUnsupported;

  /// Localized message for composerImageTooLargeMax5mb.
  ///
  /// In en, this message translates to:
  /// **'Image too large (max 5MB)'**
  String get composerImageTooLargeMax5mb;

  /// Localized message for composerVideoTooLargeMax30mb.
  ///
  /// In en, this message translates to:
  /// **'Video too large (max 30MB)'**
  String get composerVideoTooLargeMax30mb;

  /// Localized message for composerUnsupportedImageFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported image format. Use JPG, PNG, or WEBP.'**
  String get composerUnsupportedImageFormat;

  /// Localized message for composerUnsupportedVideoFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported video format. Use MP4, MOV, WEBM, or M4V.'**
  String get composerUnsupportedVideoFormat;

  /// Localized message for imageReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read the image'**
  String get imageReadFailed;

  /// Localized message for photoTooLargeMax10mb.
  ///
  /// In en, this message translates to:
  /// **'Photo too large (max 10MB)'**
  String get photoTooLargeMax10mb;

  /// Localized message for imageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid image'**
  String get imageInvalid;

  /// Localized message for postPrayedByOnePerson.
  ///
  /// In en, this message translates to:
  /// **'Prayed by 1 person'**
  String get postPrayedByOnePerson;

  /// Localized message for postPrayedByName.
  ///
  /// In en, this message translates to:
  /// **'Prayed by {name}'**
  String postPrayedByName(String name);

  /// Localized message for postPrayedByTwoPeople.
  ///
  /// In en, this message translates to:
  /// **'Prayed by 2 people'**
  String get postPrayedByTwoPeople;

  /// Localized message for postPrayedByNameAndOneOther.
  ///
  /// In en, this message translates to:
  /// **'Prayed by {name} and 1 other'**
  String postPrayedByNameAndOneOther(String name);

  /// Localized message for postPrayedByNameAndOthers.
  ///
  /// In en, this message translates to:
  /// **'Prayed by {name} and others'**
  String postPrayedByNameAndOthers(String name);

  /// Localized message for postPrayedByManyPeople.
  ///
  /// In en, this message translates to:
  /// **'Prayed by {count} people'**
  String postPrayedByManyPeople(int count);

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonWeekdaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get commonWeekdaySunday;

  /// No description provided for @commonWeekdayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get commonWeekdayMonday;

  /// No description provided for @commonWeekdayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get commonWeekdayTuesday;

  /// No description provided for @commonWeekdayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get commonWeekdayWednesday;

  /// No description provided for @commonWeekdayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get commonWeekdayThursday;

  /// No description provided for @commonWeekdayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get commonWeekdayFriday;

  /// No description provided for @commonWeekdaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get commonWeekdaySaturday;

  /// No description provided for @commonSomethingWentWrongWithReason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {reason}'**
  String commonSomethingWentWrongWithReason(String reason);

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingPrayerRegionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pray for people and regions'**
  String get onboardingPrayerRegionsTitle;

  /// No description provided for @onboardingRequestOrTestifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for prayer or share a testimony'**
  String get onboardingRequestOrTestifyTitle;

  /// No description provided for @onboardingMapWorldTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect on the world map'**
  String get onboardingMapWorldTitle;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get onboardingStart;

  /// No description provided for @reportEntityTypePost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get reportEntityTypePost;

  /// No description provided for @reportEntityTypeStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get reportEntityTypeStory;

  /// No description provided for @reportEntityTypeAlert.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get reportEntityTypeAlert;

  /// No description provided for @reportEntityTypeComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get reportEntityTypeComment;

  /// No description provided for @reportEntityTypeUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get reportEntityTypeUser;

  /// No description provided for @reportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports'**
  String get reportsEmpty;

  /// No description provided for @moderationMarkAs.
  ///
  /// In en, this message translates to:
  /// **'Mark as \"{status}\"'**
  String moderationMarkAs(String status);

  /// No description provided for @moderationRemoveContent.
  ///
  /// In en, this message translates to:
  /// **'Remove content'**
  String get moderationRemoveContent;

  /// No description provided for @moderationWarnUser.
  ///
  /// In en, this message translates to:
  /// **'Warn user'**
  String get moderationWarnUser;

  /// No description provided for @moderationSuspendDays.
  ///
  /// In en, this message translates to:
  /// **'Suspend {days} days'**
  String moderationSuspendDays(int days);

  /// No description provided for @moderationCopyReportId.
  ///
  /// In en, this message translates to:
  /// **'Copy report ID'**
  String get moderationCopyReportId;

  /// No description provided for @moderationReportMarkedReviewing.
  ///
  /// In en, this message translates to:
  /// **'Report marked as under review'**
  String get moderationReportMarkedReviewing;

  /// No description provided for @moderationReportResolved.
  ///
  /// In en, this message translates to:
  /// **'Report resolved'**
  String get moderationReportResolved;

  /// No description provided for @moderationReportDismissed.
  ///
  /// In en, this message translates to:
  /// **'Report dismissed'**
  String get moderationReportDismissed;

  /// No description provided for @moderationRemoveContentConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove content?'**
  String get moderationRemoveContentConfirmTitle;

  /// No description provided for @moderationContentRemoved.
  ///
  /// In en, this message translates to:
  /// **'Content removed'**
  String get moderationContentRemoved;

  /// No description provided for @moderationWarningRegistered.
  ///
  /// In en, this message translates to:
  /// **'Warning registered'**
  String get moderationWarningRegistered;

  /// No description provided for @moderationSuspendUserConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Suspend user?'**
  String get moderationSuspendUserConfirmTitle;

  /// No description provided for @moderationSuspendConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get moderationSuspendConfirmLabel;

  /// No description provided for @moderationSuspensionRegistered.
  ///
  /// In en, this message translates to:
  /// **'Suspension registered'**
  String get moderationSuspensionRegistered;

  /// No description provided for @moderationTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {target}'**
  String moderationTarget(String target);

  /// No description provided for @moderationReporter.
  ///
  /// In en, this message translates to:
  /// **'Reporter: {reporter}'**
  String moderationReporter(String reporter);

  /// No description provided for @moderationCommentNotFoundLocally.
  ///
  /// In en, this message translates to:
  /// **'Comment not found locally'**
  String get moderationCommentNotFoundLocally;

  /// No description provided for @moderationStoryUiPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Story (UI)'**
  String get moderationStoryUiPlaceholder;

  /// No description provided for @verificationBadgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified badge'**
  String get verificationBadgeTitle;

  /// No description provided for @verificationBadgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Highlight your profile with a verification badge.'**
  String get verificationBadgeDescription;

  /// No description provided for @verificationBenefitCredibility.
  ///
  /// In en, this message translates to:
  /// **'More credibility'**
  String get verificationBenefitCredibility;

  /// No description provided for @verificationBenefitHighlight.
  ///
  /// In en, this message translates to:
  /// **'More visibility in results'**
  String get verificationBenefitHighlight;

  /// No description provided for @verificationBenefitProtection.
  ///
  /// In en, this message translates to:
  /// **'Protection against fake profiles'**
  String get verificationBenefitProtection;

  /// No description provided for @verificationPlansTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get verificationPlansTitle;

  /// No description provided for @verificationSubjectPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get verificationSubjectPerson;

  /// No description provided for @verificationSubjectChurch.
  ///
  /// In en, this message translates to:
  /// **'Church'**
  String get verificationSubjectChurch;

  /// No description provided for @verificationBillingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get verificationBillingMonthly;

  /// No description provided for @verificationBillingYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get verificationBillingYearly;

  /// No description provided for @verificationPriceMonthly.
  ///
  /// In en, this message translates to:
  /// **'R\$ 14.90'**
  String get verificationPriceMonthly;

  /// No description provided for @verificationPriceYearly.
  ///
  /// In en, this message translates to:
  /// **'R\$ 149.90'**
  String get verificationPriceYearly;

  /// No description provided for @verificationSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get verificationSubscribe;

  /// No description provided for @verificationRestorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get verificationRestorePurchase;

  /// No description provided for @verificationRestorePhase2.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase (phase 2)'**
  String get verificationRestorePhase2;

  /// No description provided for @verificationTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get verificationTerms;

  /// No description provided for @verificationSubscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Subscription active'**
  String get verificationSubscriptionActive;

  /// No description provided for @campaignsTitle.
  ///
  /// In en, this message translates to:
  /// **'Campaigns — {location}'**
  String campaignsTitle(String location);

  /// No description provided for @campaignSortNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get campaignSortNearby;

  /// No description provided for @campaignSortPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get campaignSortPopular;

  /// No description provided for @campaignEmptyHere.
  ///
  /// In en, this message translates to:
  /// **'There are no campaigns here yet.'**
  String get campaignEmptyHere;

  /// No description provided for @campaignCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create campaign'**
  String get campaignCreateTitle;

  /// No description provided for @campaignUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This campaign is not available.'**
  String get campaignUnavailable;

  /// No description provided for @campaignTitle.
  ///
  /// In en, this message translates to:
  /// **'Campaign'**
  String get campaignTitle;

  /// No description provided for @campaignInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get campaignInvalidAmount;

  /// No description provided for @campaignPixGeneratedDemo.
  ///
  /// In en, this message translates to:
  /// **'PIX payment generated (demo)'**
  String get campaignPixGeneratedDemo;

  /// No description provided for @campaignDonationRecorded.
  ///
  /// In en, this message translates to:
  /// **'Donation recorded'**
  String get campaignDonationRecorded;

  /// No description provided for @campaignUpdatePublished.
  ///
  /// In en, this message translates to:
  /// **'Update published'**
  String get campaignUpdatePublished;

  /// No description provided for @campaignGoalAmount.
  ///
  /// In en, this message translates to:
  /// **'goal {amount}'**
  String campaignGoalAmount(String amount);

  /// No description provided for @campaignRaisedAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} raised'**
  String campaignRaisedAmount(String amount);

  /// No description provided for @campaignDeadlineAt.
  ///
  /// In en, this message translates to:
  /// **'Deadline: {time}'**
  String campaignDeadlineAt(String time);

  /// No description provided for @mapCampaignsTitle.
  ///
  /// In en, this message translates to:
  /// **'Campaigns'**
  String get mapCampaignsTitle;

  /// No description provided for @mapAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get mapAlertsTitle;

  /// No description provided for @mapCampaignsActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String mapCampaignsActiveCount(String count);

  /// No description provided for @mapAlertsActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String mapAlertsActiveCount(String count);

  /// No description provided for @mapActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active watch'**
  String get mapActiveTitle;

  /// No description provided for @mapMomentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} moments'**
  String mapMomentsCount(String count);

  /// No description provided for @mapRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} requests'**
  String mapRequestsCount(String count);

  /// No description provided for @mapAlertsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} alerts'**
  String mapAlertsCount(String count);

  /// No description provided for @mapNewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} updates'**
  String mapNewsCount(String count);

  /// No description provided for @campaignDonationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} donations'**
  String campaignDonationsCount(int count);

  /// No description provided for @campaignDonateTitle.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get campaignDonateTitle;

  /// No description provided for @paymentMethodPix.
  ///
  /// In en, this message translates to:
  /// **'PIX'**
  String get paymentMethodPix;

  /// No description provided for @paymentMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// No description provided for @campaignAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get campaignAmountLabel;

  /// No description provided for @campaignConfirmDonation.
  ///
  /// In en, this message translates to:
  /// **'Confirm donation'**
  String get campaignConfirmDonation;

  /// No description provided for @campaignSignInToDonate.
  ///
  /// In en, this message translates to:
  /// **'Sign in to donate'**
  String get campaignSignInToDonate;

  /// No description provided for @campaignPixPendingInfo.
  ///
  /// In en, this message translates to:
  /// **'With PIX, the status starts as pending and is confirmed next (demo).'**
  String get campaignPixPendingInfo;

  /// No description provided for @campaignUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get campaignUpdatesTitle;

  /// No description provided for @campaignOnlyCreatorPublishes.
  ///
  /// In en, this message translates to:
  /// **'Only the creator can publish'**
  String get campaignOnlyCreatorPublishes;

  /// No description provided for @campaignWriteUpdate.
  ///
  /// In en, this message translates to:
  /// **'Write an update'**
  String get campaignWriteUpdate;

  /// No description provided for @campaignNoUpdatesYet.
  ///
  /// In en, this message translates to:
  /// **'No updates yet.'**
  String get campaignNoUpdatesYet;

  /// No description provided for @campaignCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments ({count})'**
  String campaignCommentsTitle(int count);

  /// No description provided for @campaignLocationWorld.
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get campaignLocationWorld;

  /// No description provided for @campaignLocationBrazil.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get campaignLocationBrazil;

  /// No description provided for @campaignLocationGoiania.
  ///
  /// In en, this message translates to:
  /// **'Goiânia, GO'**
  String get campaignLocationGoiania;

  /// No description provided for @campaignLocationSaoPaulo.
  ///
  /// In en, this message translates to:
  /// **'São Paulo, SP'**
  String get campaignLocationSaoPaulo;

  /// No description provided for @campaignChooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get campaignChooseLocation;

  /// No description provided for @campaignEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get campaignEnterTitle;

  /// No description provided for @campaignEnterDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter a description'**
  String get campaignEnterDescription;

  /// No description provided for @campaignEnterValidGoal.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid goal'**
  String get campaignEnterValidGoal;

  /// No description provided for @campaignCreated.
  ///
  /// In en, this message translates to:
  /// **'Campaign created'**
  String get campaignCreated;

  /// No description provided for @campaignFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get campaignFieldTitle;

  /// No description provided for @campaignGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal (R\$)'**
  String get campaignGoalLabel;

  /// No description provided for @campaignCategoryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get campaignCategoryFieldLabel;

  /// No description provided for @campaignSetDeadlineOptional.
  ///
  /// In en, this message translates to:
  /// **'Set deadline (optional)'**
  String get campaignSetDeadlineOptional;

  /// No description provided for @campaignImageUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Image (URL)'**
  String get campaignImageUrlLabel;

  /// No description provided for @campaignDonationsStoredInfo.
  ///
  /// In en, this message translates to:
  /// **'PIX and card donations are stored in \"donations\".'**
  String get campaignDonationsStoredInfo;

  /// No description provided for @campaignPublishCta.
  ///
  /// In en, this message translates to:
  /// **'Publish campaign'**
  String get campaignPublishCta;

  /// No description provided for @prayerChallengesTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer challenges'**
  String get prayerChallengesTitle;

  /// No description provided for @prayerChallengesFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get prayerChallengesFilterActive;

  /// No description provided for @prayerChallengesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get prayerChallengesFilterAll;

  /// No description provided for @prayerChallengesEmptyActive.
  ///
  /// In en, this message translates to:
  /// **'No active challenges right now.'**
  String get prayerChallengesEmptyActive;

  /// No description provided for @prayerChallengesEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No challenges found.'**
  String get prayerChallengesEmptyAll;

  /// No description provided for @prayerChallengeStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in {duration}'**
  String prayerChallengeStartsIn(String duration);

  /// No description provided for @prayerChallengeEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get prayerChallengeEnded;

  /// No description provided for @prayerChallengeEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Ends in {duration}'**
  String prayerChallengeEndsIn(String duration);

  /// No description provided for @prayerChallengeNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get prayerChallengeNoDescription;

  /// No description provided for @prayerChallengeParticipating.
  ///
  /// In en, this message translates to:
  /// **'Participating'**
  String get prayerChallengeParticipating;

  /// No description provided for @prayerChallengeParticipantsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} participants'**
  String prayerChallengeParticipantsCount(String count);

  /// No description provided for @prayerChallengeRegionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Challenge region unavailable'**
  String get prayerChallengeRegionUnavailable;

  /// No description provided for @prayerChallengeRegionFallback.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get prayerChallengeRegionFallback;

  /// No description provided for @prayerChallengeShareText.
  ///
  /// In en, this message translates to:
  /// **'I\'m participating in the prayer challenge: \"{title}\".'**
  String prayerChallengeShareText(String title);

  /// No description provided for @prayerChallengeShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied to share'**
  String get prayerChallengeShareCopied;

  /// No description provided for @prayerChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenge'**
  String get prayerChallengeTitle;

  /// No description provided for @prayerChallengeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Challenge not found.'**
  String get prayerChallengeNotFound;

  /// No description provided for @prayerChallengeShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get prayerChallengeShare;

  /// No description provided for @prayerChallengeLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave challenge'**
  String get prayerChallengeLeaveAction;

  /// No description provided for @prayerChallengeJoinAction.
  ///
  /// In en, this message translates to:
  /// **'Join challenge'**
  String get prayerChallengeJoinAction;

  /// No description provided for @prayerChallengeProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get prayerChallengeProgressTitle;

  /// No description provided for @prayerChallengeParticipantsProgress.
  ///
  /// In en, this message translates to:
  /// **'Participants: {current}{goal}'**
  String prayerChallengeParticipantsProgress(String current, String goal);

  /// No description provided for @prayerChallengeTimeProgress.
  ///
  /// In en, this message translates to:
  /// **'Time: {current}{goal}'**
  String prayerChallengeTimeProgress(String current, String goal);

  /// No description provided for @prayerChallengeTopIntercessors.
  ///
  /// In en, this message translates to:
  /// **'Top intercessors'**
  String get prayerChallengeTopIntercessors;

  /// No description provided for @prayerChallengeRankSessions.
  ///
  /// In en, this message translates to:
  /// **'{duration} • {sessions} sessions'**
  String prayerChallengeRankSessions(String duration, String sessions);

  /// No description provided for @prayerChallengeTopCommunities.
  ///
  /// In en, this message translates to:
  /// **'Top communities'**
  String get prayerChallengeTopCommunities;

  /// No description provided for @prayerChallengeTopCountries.
  ///
  /// In en, this message translates to:
  /// **'Top countries'**
  String get prayerChallengeTopCountries;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt': {
  switch (locale.countryCode) {
    case 'BR': return AppLocalizationsPtBr();
   }
  break;
   }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'es': return AppLocalizationsEs();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
