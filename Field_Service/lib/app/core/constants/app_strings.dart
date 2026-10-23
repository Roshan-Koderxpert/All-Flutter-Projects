import 'package:get/get.dart';

class AppStrings {
  AppStrings._();


  // ── Auth ──────────────────────────────────────
  static String get signIn => 'sign_in'.tr;
  static String get login => 'login'.tr;
  static String get next => 'next'.tr;
  static const String selectDB               = 'Select Database';
  static String get loginServerSubtitle => 'login_server_subtitle'.tr;
  static String get loginCredentialSubtitle => 'login_credential_subtitle'.tr;


  // ── Validation ────────────────────────────────
  static String get fieldRequired => 'field_required'.tr;
  static String get usernameRequired => 'username_required'.tr;
  static String get passwordRequired => 'password_required'.tr;
  static String get passwordMinLength => 'password_min_length'.tr;


  // ── Errors ────────────────────────────────────
  static const String errorNoInternet =
      'No network connection. Connect to the internet to sign in or refresh from the server.';

  static const String fieldServiceModuleRequiredTitle = 'Field Service required';
  static const String fieldServiceModuleRequiredMessage =
      'The Field Service module is not installed on this database. '
      'Please install the Field Service module in Odoo before using this app.';
  static const String backToLogin = 'Back to login';

  // ── Offline mode ─────────────────────────────
  static String get offlineBannerMessage => 'offline_banner_message'.tr;


  // Bottom navigation
  static String get navOrder => 'nav_order'.tr;
  static String get navMap => 'nav_map'.tr;
  static String get navMyProfile => 'nav_my_profile'.tr;

  // Order tab
  static String get orderFilterNew => 'order_filter_new'.tr;
  static String get orderEmpty => 'order_empty'.tr;



  //Delivery screen
  static const String deliveriesSubtitle     = 'Deliveries';
  static const String noDeliveries           = 'No deliveries found.';
  static const String validateDelivery          = 'Validate Delivery';
  static const String validateDeliveryMessage   = 'Are you sure you want to validate this delivery? This will mark all products as delivered.';
  static const String cancelDelivery          = 'Cancel';
  static const String validate          = 'Validate';
  static const String deliverySuccess          = 'Validation queued — will sync when back online.';
  static const String deliverySuccessMessage          = 'Delivery validated successfully!';
  static const String failedDelivery          = 'Failed to validate delivery. Check Odoo logs.';
  static const String noProductsFound          = 'No products found.';
  static const String addInternalNote          = 'Add an internal note that will be printed on the Picking Operations sheet';


  // ── Invoice Screen ───────────────────────────────────


  static const String invoiceDraft              = 'Draft Invoice';
  static const String invoiceConfirmTitle       = 'Confirm Invoice';
  static const String invoiceConfirmMessage     = 'Are you sure you want to confirm this invoice? This action cannot be undone.';
  static const String invoiceConfirmCancel      = 'Cancel';
  static const String invoiceConfirmButton      = 'Confirm';
  static const String invoiceConfirmQueued      = 'Confirm queued — will sync when back online.';
  static const String invoiceConfirmSuccess     = 'Invoice confirmed successfully!';
  static const String invoiceConfirmFailed      = 'Failed to confirm invoice.';
  static const String invoiceLoadFailed         = 'Failed to load invoice details.';
  static const String invoiceNoLines            = 'No invoice lines.';
  static const String invoiceNoFound            = 'No invoices found.';
  static const String invoiceListTitle          = 'Invoices';
  static const String invoiceHeaderCustomer     = 'Customer';
  static const String invoiceHeaderDate         = 'Invoice Date';
  static const String invoiceHeaderPaymentTerms = 'Payment Terms';
  static const String invoiceHeaderDeliveryDate = 'Delivery Date';
  static const String invoiceHeaderPaymentState = 'Payment State';
  static const String invoiceHeaderJournal      = 'Journal';
  static const String invoiceHeaderCompany      = 'Company';
  static const String invoiceHeaderLines        = 'Invoice Lines';
  static const String invoiceColProduct         = 'Product';
  static const String invoiceColQty             = 'Qty';
  static const String invoiceColUom             = 'UoM';
  static const String invoiceColPrice           = 'Price';
  static const String invoiceColTaxes           = 'Taxes';
  static const String invoiceColAmount          = 'Amount';
  static const String invoiceTotalUntaxed       = 'Untaxed Amount:';
  static const String invoiceTotalLabel         = 'Total:';
  static const String invoiceStepDraft          = 'Draft';
  static const String invoiceStepPosted         = 'Posted';


  // ── Map ───────────────────────────────────────
  static const String mapOrders               = 'Orders';
  static const String mapNoLocationLabel      = 'No location label';
  static const String mapNoCoords             = 'No coords';
  static const String mapNoCoordSnack         = 'No location coordinates for this order';
  static const String mapDialogLocation       = 'Location: ';
  static const String mapDialogStage          = 'Stage: ';
  static const String mapDialogAssigned       = 'Assigned: ';
  static const String mapDialogClose          = 'Close';
  static const String mapDialogOpen           = 'Open';

  // ── My Profile ────────────────────────────────
  static const String profileLoadError          = 'Could not load profile details.';
  static const String profileSave               = 'Save';
  static const String profileUpdateSuccess      = 'Profile updated successfully.';
  static const String profileUpdateFailed       = 'Failed to update profile.';
  static const String profileFieldPosition      = 'Position';
  static const String profileFieldWorkMobile    = 'Work Mobile';
  static const String profileFieldWorkPhone     = 'Work Phone';
  static const String profileFieldWorkEmail     = 'Work Email';
  static const String profileFieldWorkLocation  = 'Work Location';
  static const String profileFieldManager       = 'Manager';
  static const String profileFieldCoach         = 'Coach';
  static const String profileFieldLanguage      = 'Language';
  static const String profileFieldTimeZone      = 'Time Zone';
  static const String profileFieldEmailSig      = 'Email Signature';
  static const String profileFieldWarehouse     = 'Default Warehouse';
  static const String profileRetry              = 'Retry';



  // ── Order Create ──────────────────────────────

  static const String orderLoadingForm              = 'Loading form…';
  static const String orderLoadingOrderDetails      = 'Loading order details…';
  static const String orderDescriptionTitle         = 'Description';
  static const String orderDescriptionHint          = 'Add Description for the Order';
  static const String orderResolutionTitle          = 'Resolution';
  static const String orderResolutionHint           = 'Enter Resolution for the Order';
  static const String orderPriority                 = 'Priority';
  static const String orderSaving                   = 'Saving...';
  static const String orderSave                     = 'Save';
  static const String orderCancel                   = 'Cancel';
  static const String orderTabPlanning              = 'Planning';
  static const String orderTabInstructions          = 'Instructions';
  static const String orderTabExecution             = 'Execution';
  static const String orderTabMap                   = 'Map';
  static const String orderTabTimesheet             = 'Timesheet';
  static const String orderInstructionsTitle        = 'Instructions';
  static const String orderInstructionsHint         = 'Enter instructions';
  static const String orderLocationDirectionsTitle  = 'Location Directions';
  static const String orderLocationDirectionsHint   = 'Enter location directions';
  static const String orderExecutionTitle           = 'Execution';
  static const String orderActualStart              = 'Actual Start';
  static const String orderActualEnd                = 'Actual End';
  static const String orderActualDuration           = 'Actual Duration';
  static const String orderSelectDateTime           = 'Select date & time';
  static const String orderTimesheetTitle           = 'Timesheet';
  static const String orderMapTitle                 = 'Map';
  static const String orderMapLocation              = 'Location';
  static const String orderMapNoLatLng              = 'Latitude / longitude not found for this order.';
  static const String orderMapAfterSave             = 'Map is available after saving the order.';
  static const String orderMapCoordError            = 'Could not load map coordinates.';
  static const String orderMapResolveError          = 'Could not resolve order location.';
  static const String orderPlanningTitle            = 'Requirements & Schedule Details';
  static const String orderRequestWorkers           = 'Request Workers';
  static const String orderWorkerColName            = 'Name';
  static const String orderWorkerColPhone           = 'Phone';
  static const String orderWorkerColEmail           = 'Email';
  static const String orderWorkerColSchedule        = 'Working Schedule';
  static const String orderAddLine                  = 'Add a line';
  static const String orderTimesheetColDate         = 'Date';
  static const String orderTimesheetColType         = 'Timesheet Type';
  static const String orderTimesheetColEmployee     = 'Employee';
  static const String orderTimesheetColDescription  = 'Description';
  static const String orderTimesheetColTimespent    = 'Timespent';
  static const String orderNotFound                 = 'Order not found.';
  static const String orderSaleNotFound             = 'Sale order not found for this order.';
  static const String orderSaveSuccess              = 'Order saved successfully';
  static const String orderUpdateSuccess            = 'Order updated successfully';
  static const String orderSaveFailed               = 'Save failed: ';
  static const String orderSelectRequired           = 'Please select ';
  static const String orderPrefillError             = 'Could not prefill order data: ';
  static const String orderStockNone                = 'No stock available for this order.';
  static const String orderStockOpenFailed          = 'Failed to open stock: ';
  static const String orderFieldsLoadFailed         = 'Failed to load Odoo fields: ';
  static const String orderVehicleStockLoadFailed   = 'Failed to load vehicle stock: ';
  static const String orderTimesheetSaveOffline     = 'Timesheet saved on device only. Odoo create failed — check server fields (e.g. project_id) and logs.';
  static const String orderTimesheetWorkLog         = 'Work log';
  static const String orderTransferAddLine          = 'Please add at least one product line.';
  static const String orderTransferSaveFirst        = 'Save the order first before creating a transfer.';
  static const String orderTransferNoDestination    = 'Destination location could not be resolved. Please check the vehicle has a stock location configured in Odoo.';
  static const String orderTransferQueued           = 'Transfer queued for sync (offline).';
  static const String orderTransferSuccess          = 'Transfer created successfully!';
  static const String orderTransferFailed           = 'Create transfer failed.';
  static const String orderTransferFailedError      = 'Create transfer failed: ';
  static const String orderVehicleStockTitle        = 'Load Vehicle Stock';
  static const String orderVehicleStockFsmOrder     = 'FSM Order';
  static const String orderVehicleStockVehicle      = 'Vehicle';
  static const String orderVehicleStockDest         = 'Destination Location';
  static const String orderVehicleStockProducts     = 'Products';
  static const String orderVehicleStockProduct      = 'Product';
  static const String orderVehicleStockAvailQty     = 'Avail. Qty';
  static const String orderVehicleStockQuantity     = 'Quantity';
  static const String orderVehicleStockLot          = 'Lot/Serial';
  static const String orderVehicleStockNoProducts   = 'No products available for this vehicle yet.';
  static const String orderVehicleStockCreateTransfer = 'Create Transfer';
  static const String orderVehicleStockSelect       = 'Select';
  static const String orderVehicleStockLoadButton   = 'Load Vehicle Stock';
  static const String orderStockTitle               = 'Stock';
  static const String orderStockNoData              = 'No stock data found.';
  static const String orderStockColLocation         = 'Location';
  static const String orderStockColProduct          = 'Product';
  static const String orderStockColLot              = 'Lot/Serial Number';
  static const String orderStockColOnHand           = 'On Hand Quantity';
  static const String orderStockColReserved         = 'Reserved Qty';
  static const String orderTimesheetLogTitle        = 'Confirmation Time Spent';
  static const String orderTimesheetLogTimeSpent    = 'Time Spent: ';
  static const String orderTimesheetLogActivity     = 'Describe your activity';
  static const String orderTimesheetLogButton       = 'Log Time';
  static const String orderTimesheetResumeTimer     = 'Resume Timer';
  static const String orderTimesheetDeleteTimer     = 'Delete';
  static const String orderStockActions             = 'Stock actions';
  static const String orderStockActionStock         = 'Stock';
  static const String orderStockActionProducts      = 'Products';
  static const String orderStockActionSaleOrder     = 'Sale Order';
  static const String orderStockActionInvoices      = 'Invoices';
  static const String orderProductsButton           = 'Products';
  static const String orderNewOrder                 = 'New Order';





  // After orderStockActionInvoices line, add:
  static const String orderWorksheetButton          = 'Worksheet';
  static const String orderWorksheetListTitle       = 'Worksheets';
  static const String orderWorksheetNoRecords       = 'No worksheet records found.';
  static const String orderWorksheetLoadFailed      = 'Failed to load worksheets.';
  static const String orderWorksheetFormTitle       = 'Worksheet Detail';
  static const String orderWorksheetFormLoadFailed  = 'Failed to load worksheet fields.';
  static const String orderWorksheetColCreatedOn    = 'Created On';
  static const String orderWorksheetColName         = 'Name';






}