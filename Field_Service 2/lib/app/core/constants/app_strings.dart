import 'package:get/get.dart';

/// Every string in this class goes through GetX's '.tr' lookup.
/// That means TranslationService can swap them live when the user changes language.
class AppStrings {
  AppStrings._();

  // ── App ──────────────────────────────────────────────────────────────
  static String get appFullName => 'app_full_name'.tr;

  // ── Auth ──────────────────────────────────────────────────────────────
  static String get signIn => 'sign_in'.tr;
  static String get signOut => 'sign_out'.tr;
  static String get login => 'login'.tr;
  static String get next => 'next'.tr;
  static String get selectDB => 'select_db'.tr;
  static String get loginServerSubtitle => 'login_server_subtitle'.tr;
  static String get loginCredentialSubtitle => 'login_credential_subtitle'.tr;
  static String get authModuleNotInstalledTitle =>
      'auth_module_not_installed_title'.tr;
  static String get authModuleNotInstalledMessage =>
      'auth_module_not_installed_message'.tr;
  static String get authBackToLogin => 'auth_back_to_login'.tr;

  // ── Validation ────────────────────────────────────────────────────────
  static String get fieldRequired => 'field_required'.tr;
  static String get usernameRequired => 'username_required'.tr;
  static String get passwordRequired => 'password_required'.tr;
  static String get passwordMinLength => 'password_min_length'.tr;

  // ── Errors ────────────────────────────────────────────────────────────
  static String get errorNoInternet => 'error_no_internet'.tr;

  // ── Offline mode ─────────────────────────────────────────────────────
  static String get offlineBannerMessage => 'offline_banner_message'.tr;

  // ── Bottom navigation ─────────────────────────────────────────────────
  static String get navOrder => 'nav_order'.tr;
  static String get navMap => 'nav_map'.tr;
  static String get navMyProfile => 'nav_my_profile'.tr;

  // ── Order tab ─────────────────────────────────────────────────────────
  static String get orderFilterNew => 'order_filter_new'.tr;
  static String get orderEmpty => 'order_empty'.tr;
  static String get orderNewOrder => 'order_new_order'.tr;
  static String get orderProductsButton => 'order_products_button'.tr;
  static String get orderWorksheetButton => 'order_worksheet_button'.tr;
  static String get orderStockActions => 'order_stock_actions'.tr;
  static String get orderStockActionStock => 'order_stock_action_stock'.tr;
  static String get orderStockActionProducts => 'order_stock_action_products'.tr;
  static String get orderStockActionSaleOrder => 'order_stock_action_sale_order'.tr;
  static String get orderStockActionInvoices => 'order_stock_action_invoices'.tr;

  // ── Delivery screen ───────────────────────────────────────────────────
  static String get deliveriesSubtitle => 'deliveries_subtitle'.tr;
  static String get noDeliveries => 'no_deliveries'.tr;
  static String get validateDelivery => 'validate_delivery'.tr;
  static String get validateDeliveryMessage => 'validate_delivery_message'.tr;
  static String get cancelDelivery => 'cancel_delivery'.tr;
  static String get validate => 'validate'.tr;
  static String get deliverySuccess => 'delivery_success'.tr;
  static String get deliverySuccessMessage => 'delivery_success_message'.tr;
  static String get failedDelivery => 'failed_delivery'.tr;
  static String get noProductsFound => 'no_products_found'.tr;
  static String get addInternalNote => 'add_internal_note'.tr;

  // ── Invoice Screen ────────────────────────────────────────────────────
  static String get invoiceDraft => 'invoice_draft'.tr;
  static String get invoiceConfirmTitle => 'invoice_confirm_title'.tr;
  static String get invoiceConfirmMessage => 'invoice_confirm_message'.tr;
  static String get invoiceConfirmCancel => 'invoice_confirm_cancel'.tr;
  static String get invoiceConfirmButton => 'invoice_confirm_button'.tr;
  static String get invoiceConfirmQueued => 'invoice_confirm_queued'.tr;
  static String get invoiceConfirmSuccess => 'invoice_confirm_success'.tr;
  static String get invoiceConfirmFailed => 'invoice_confirm_failed'.tr;
  static String get invoiceLoadFailed => 'invoice_load_failed'.tr;
  static String get invoiceNoLines => 'invoice_no_lines'.tr;
  static String get invoiceNoFound => 'invoice_no_found'.tr;
  static String get invoiceListTitle => 'invoice_list_title'.tr;
  static String get invoiceHeaderCustomer => 'invoice_header_customer'.tr;
  static String get invoiceHeaderDate => 'invoice_header_date'.tr;
  static String get invoiceHeaderPaymentTerms => 'invoice_header_payment_terms'.tr;
  static String get invoiceHeaderDeliveryDate => 'invoice_header_delivery_date'.tr;
  static String get invoiceHeaderPaymentState => 'invoice_header_payment_state'.tr;
  static String get invoiceHeaderJournal => 'invoice_header_journal'.tr;
  static String get invoiceHeaderCompany => 'invoice_header_company'.tr;
  static String get invoiceHeaderLines => 'invoice_header_lines'.tr;
  static String get invoiceColProduct => 'invoice_col_product'.tr;
  static String get invoiceColQty => 'invoice_col_qty'.tr;
  static String get invoiceColUom => 'invoice_col_uom'.tr;
  static String get invoiceColPrice => 'invoice_col_price'.tr;
  static String get invoiceColTaxes => 'invoice_col_taxes'.tr;
  static String get invoiceColAmount => 'invoice_col_amount'.tr;
  static String get invoiceTotalUntaxed => 'invoice_total_untaxed'.tr;
  static String get invoiceTotalLabel => 'invoice_total_label'.tr;
  static String get invoiceStepDraft => 'invoice_step_draft'.tr;
  static String get invoiceStepPosted => 'invoice_step_posted'.tr;

  // ── Map ───────────────────────────────────────────────────────────────
  static String get mapOrders => 'map_orders'.tr;
  static String get mapNoLocationLabel => 'map_no_location_label'.tr;
  static String get mapNoCoords => 'map_no_coords'.tr;
  static String get mapNoCoordSnack => 'map_no_coord_snack'.tr;
  static String get mapDialogLocation => 'map_dialog_location'.tr;
  static String get mapDialogStage => 'map_dialog_stage'.tr;
  static String get mapDialogAssigned => 'map_dialog_assigned'.tr;
  static String get mapDialogClose => 'map_dialog_close'.tr;
  static String get mapDialogOpen => 'map_dialog_open'.tr;

  // ── My Profile ────────────────────────────────────────────────────────
  static String get profileLoadError => 'profile_load_error'.tr;
  static String get profileSave => 'profile_save'.tr;
  static String get profileUpdateSuccess => 'profile_update_success'.tr;
  static String get profileUpdateFailed => 'profile_update_failed'.tr;
  static String get profileFieldPosition => 'profile_field_position'.tr;
  static String get profileFieldWorkMobile => 'profile_field_work_mobile'.tr;
  static String get profileFieldWorkPhone => 'profile_field_work_phone'.tr;
  static String get profileFieldWorkEmail => 'profile_field_work_email'.tr;
  static String get profileFieldWorkLocation => 'profile_field_work_location'.tr;
  static String get profileFieldManager => 'profile_field_manager'.tr;
  static String get profileFieldCoach => 'profile_field_coach'.tr;
  static String get profileFieldLanguage => 'profile_field_language'.tr;
  static String get profileFieldTimeZone => 'profile_field_time_zone'.tr;
  static String get profileFieldEmailSig => 'profile_field_email_sig'.tr;
  static String get profileFieldWarehouse => 'profile_field_warehouse'.tr;
  static String get profileRetry => 'profile_retry'.tr;

  // ── Profile Tab ───────────────────────────────────────────────────────
  static String get profileTabTitle => 'profile_tab_title'.tr;
  static String get profileCompanies => 'profile_companies'.tr;
  static String get profileReset => 'profile_reset'.tr;
  static String get profileConfirm => 'profile_confirm'.tr;
  static String get profileDocumentation => 'profile_documentation'.tr;
  static String get profileSupport => 'profile_support'.tr;
  static String get profileDarkMode => 'profile_dark_mode'.tr;
  static String get profileMyProfile => 'profile_my_profile'.tr;
  static String get profileMyOdooAccount => 'profile_my_odoo_account'.tr;
  static String get profileLogout => 'profile_logout'.tr;
  static String get profileLogoutConfirm => 'profile_logout_confirm'.tr;
  static String get profileLanguageMenu => 'profile_language_menu'.tr;

  // ── Order Create — form field labels ─────────────────────────────────
  static String get orderFieldPartner => 'order_field_partner'.tr;
  static String get orderFieldTemplate => 'order_field_template'.tr;
  static String get orderFieldType => 'order_field_type'.tr;
  static String get orderFieldLocation => 'order_field_location'.tr;
  static String get orderFieldAssignedTo => 'order_field_assigned_to'.tr;
  static String get orderFieldVehicle => 'order_field_vehicle'.tr;
  static String get orderFieldCompany => 'order_field_company'.tr;
  static String get orderFieldWorksheetTemplate => 'order_field_worksheet_template'.tr;
  static String get orderFieldEarliestRequestDate => 'order_field_earliest_request_date'.tr;
  static String get orderFieldLatestRequestDate => 'order_field_latest_request_date'.tr;
  static String get orderFieldScheduledStart => 'order_field_scheduled_start'.tr;
  static String get orderFieldScheduledDuration => 'order_field_scheduled_duration'.tr;
  static String get orderFieldScheduledEnd => 'order_field_scheduled_end'.tr;

  // ── Order Create — action buttons ────────────────────────────────────
  static String get orderActionComplete => 'order_action_complete'.tr;
  static String get orderActionCancelOrder => 'order_action_cancel_order'.tr;
  static String get orderStageUpdated => 'order_stage_updated'.tr;
  static String get orderStageUpdateFailed => 'order_stage_update_failed'.tr;
  static String get orderTransferFailedDetail => 'order_transfer_failed_detail'.tr;

  // ── Order Create ──────────────────────────────────────────────────────
  static String get orderLoadingForm => 'order_loading_form'.tr;
  static String get orderLoadingOrderDetails => 'order_loading_order_details'.tr;
  static String get orderDescriptionTitle => 'order_description_title'.tr;
  static String get orderDescriptionHint => 'order_description_hint'.tr;
  static String get orderResolutionTitle => 'order_resolution_title'.tr;
  static String get orderResolutionHint => 'order_resolution_hint'.tr;
  static String get orderPriority => 'order_priority'.tr;
  static String get orderSaving => 'order_saving'.tr;
  static String get orderSave => 'order_save'.tr;
  static String get orderCancel => 'order_cancel'.tr;
  static String get orderTabPlanning => 'order_tab_planning'.tr;
  static String get orderTabInstructions => 'order_tab_instructions'.tr;
  static String get orderTabExecution => 'order_tab_execution'.tr;
  static String get orderTabMap => 'order_tab_map'.tr;
  static String get orderTabTimesheet => 'order_tab_timesheet'.tr;
  static String get orderInstructionsTitle => 'order_instructions_title'.tr;
  static String get orderInstructionsHint => 'order_instructions_hint'.tr;
  static String get orderLocationDirectionsTitle => 'order_location_directions_title'.tr;
  static String get orderLocationDirectionsHint => 'order_location_directions_hint'.tr;
  static String get orderExecutionTitle => 'order_execution_title'.tr;
  static String get orderActualStart => 'order_actual_start'.tr;
  static String get orderActualEnd => 'order_actual_end'.tr;
  static String get orderActualDuration => 'order_actual_duration'.tr;
  static String get orderSelectDateTime => 'order_select_date_time'.tr;
  static String get orderTimesheetTitle => 'order_timesheet_title'.tr;
  static String get orderMapTitle => 'order_map_title'.tr;
  static String get orderMapLocation => 'order_map_location'.tr;
  static String get orderMapNoLatLng => 'order_map_no_lat_lng'.tr;
  static String get orderMapAfterSave => 'order_map_after_save'.tr;
  static String get orderMapCoordError => 'order_map_coord_error'.tr;
  static String get orderMapResolveError => 'order_map_resolve_error'.tr;
  static String get orderPlanningTitle => 'order_planning_title'.tr;
  static String get orderRequestWorkers => 'order_request_workers'.tr;
  static String get orderWorkerColName => 'order_worker_col_name'.tr;
  static String get orderWorkerColPhone => 'order_worker_col_phone'.tr;
  static String get orderWorkerColEmail => 'order_worker_col_email'.tr;
  static String get orderWorkerColSchedule => 'order_worker_col_schedule'.tr;
  static String get orderAddLine => 'order_add_line'.tr;
  static String get orderTimesheetColDate => 'order_timesheet_col_date'.tr;
  static String get orderTimesheetColType => 'order_timesheet_col_type'.tr;
  static String get orderTimesheetColEmployee => 'order_timesheet_col_employee'.tr;
  static String get orderTimesheetColDescription => 'order_timesheet_col_description'.tr;
  static String get orderTimesheetColTimespent => 'order_timesheet_col_timespent'.tr;
  static String get orderNotFound => 'order_not_found'.tr;
  static String get orderSaleNotFound => 'order_sale_not_found'.tr;
  static String get orderSaveSuccess => 'order_save_success'.tr;
  static String get orderUpdateSuccess => 'order_update_success'.tr;
  static String get orderSaveFailed => 'order_save_failed'.tr;
  static String get orderSelectRequired => 'order_select_required'.tr;
  static String get orderPrefillError => 'order_prefill_error'.tr;
  static String get orderStockNone => 'order_stock_none'.tr;
  static String get orderStockOpenFailed => 'order_stock_open_failed'.tr;
  static String get orderFieldsLoadFailed => 'order_fields_load_failed'.tr;
  static String get orderVehicleStockLoadFailed => 'order_vehicle_stock_load_failed'.tr;
  static String get orderTimesheetSaveOffline => 'order_timesheet_save_offline'.tr;
  static String get orderTimesheetWorkLog => 'order_timesheet_work_log'.tr;
  static String get orderTransferAddLine => 'order_transfer_add_line'.tr;
  static String get orderTransferSaveFirst => 'order_transfer_save_first'.tr;
  static String get orderTransferNoDestination => 'order_transfer_no_destination'.tr;
  static String get orderTransferQueued => 'order_transfer_queued'.tr;
  static String get orderTransferSuccess => 'order_transfer_success'.tr;
  static String get orderTransferFailed => 'order_transfer_failed'.tr;
  static String get orderTransferFailedError => 'order_transfer_failed_error'.tr;
  static String get orderVehicleStockTitle => 'order_vehicle_stock_title'.tr;
  static String get orderVehicleStockFsmOrder => 'order_vehicle_stock_fsm_order'.tr;
  static String get orderVehicleStockVehicle => 'order_vehicle_stock_vehicle'.tr;
  static String get orderVehicleStockDest => 'order_vehicle_stock_dest'.tr;
  static String get orderVehicleStockProducts => 'order_vehicle_stock_products'.tr;
  static String get orderVehicleStockProduct => 'order_vehicle_stock_product'.tr;
  static String get orderVehicleStockAvailQty => 'order_vehicle_stock_avail_qty'.tr;
  static String get orderVehicleStockQuantity => 'order_vehicle_stock_quantity'.tr;
  static String get orderVehicleStockLot => 'order_vehicle_stock_lot'.tr;
  static String get orderVehicleStockNoProducts => 'order_vehicle_stock_no_products'.tr;
  static String get orderVehicleStockCreateTransfer => 'order_vehicle_stock_create_transfer'.tr;
  static String get orderVehicleStockSelect => 'order_vehicle_stock_select'.tr;
  static String get orderVehicleStockLoadButton => 'order_vehicle_stock_load_button'.tr;
  static String get orderStockTitle => 'order_stock_title'.tr;
  static String get orderStockNoData => 'order_stock_no_data'.tr;
  static String get orderStockColLocation => 'order_stock_col_location'.tr;
  static String get orderStockColProduct => 'order_stock_col_product'.tr;
  static String get orderStockColLot => 'order_stock_col_lot'.tr;
  static String get orderStockColOnHand => 'order_stock_col_on_hand'.tr;
  static String get orderStockColReserved => 'order_stock_col_reserved'.tr;
  static String get orderTimesheetLogTitle => 'order_timesheet_log_title'.tr;
  static String get orderTimesheetLogTimeSpent => 'order_timesheet_log_time_spent'.tr;
  static String get orderTimesheetLogActivity => 'order_timesheet_log_activity'.tr;
  static String get orderTimesheetLogButton => 'order_timesheet_log_button'.tr;
  static String get orderTimesheetResumeTimer => 'order_timesheet_resume_timer'.tr;
  static String get orderTimesheetDeleteTimer => 'order_timesheet_delete_timer'.tr;

  // ── Worksheet ─────────────────────────────────────────────────────────
  static String get orderWorksheetListTitle => 'order_worksheet_list_title'.tr;
  static String get orderWorksheetNoRecords => 'order_worksheet_no_records'.tr;
  static String get orderWorksheetLoadFailed => 'order_worksheet_load_failed'.tr;
  static String get orderWorksheetFormTitle => 'order_worksheet_form_title'.tr;
  static String get orderWorksheetFormLoadFailed => 'order_worksheet_form_load_failed'.tr;
  static String get orderWorksheetColCreatedOn => 'order_worksheet_col_created_on'.tr;
  static String get orderWorksheetColName => 'order_worksheet_col_name'.tr;

  // ── Translation Download UI ───────────────────────────────────────────
  static String get langDownloading => 'lang_downloading'.tr;
  static String get langDownloadComplete => 'lang_download_complete'.tr;
  static String get langDownloadFailed => 'lang_download_failed'.tr;


  // ── Sale Order ────────────────────────────────────────────────────────
  static String get saleOrderTitle               => 'sale_order_title'.tr;
  static String get saleOrderPendingOffline       => 'sale_order_pending_offline'.tr;
  static String get saleOrderCreateInvoice        => 'sale_order_create_invoice'.tr;
  static String get saleOrderDelivery             => 'sale_order_delivery'.tr;
  static String get saleOrderInvoices             => 'sale_order_invoices'.tr;
  static String get saleOrderRetry                => 'sale_order_retry'.tr;
  static String get saleOrderNoFound              => 'sale_order_no_found'.tr;
  static String get saleOrderLoadFailed           => 'sale_order_load_failed'.tr;
  static String get saleOrderOfflineSnack         => 'sale_order_offline_snack'.tr;
  static String get saleOrderValidateDeliveryFirst => 'sale_order_validate_delivery_first'.tr;
  static String get saleOrderNotFoundSnack        => 'sale_order_not_found_snack'.tr;
  static String get saleOrderTabOrderLines        => 'sale_order_tab_order_lines'.tr;
  static String get saleOrderTabQuoteBuilder      => 'sale_order_tab_quote_builder'.tr;
  static String get saleOrderTabOtherInfo         => 'sale_order_tab_other_info'.tr;
  static String get saleOrderTabCustomerSig       => 'sale_order_tab_customer_sig'.tr;
  static String get saleOrderColProduct           => 'sale_order_col_product'.tr;
  static String get saleOrderColQuantity          => 'sale_order_col_quantity'.tr;
  static String get saleOrderColDelivered         => 'sale_order_col_delivered'.tr;
  static String get saleOrderColInvoiced          => 'sale_order_col_invoiced'.tr;
  static String get saleOrderColUom               => 'sale_order_col_uom'.tr;
  static String get saleOrderColUnitPrice         => 'sale_order_col_unit_price'.tr;
  static String get saleOrderColTaxes             => 'sale_order_col_taxes'.tr;
  static String get saleOrderColAmount            => 'sale_order_col_amount'.tr;
  static String get saleOrderNoProducts           => 'sale_order_no_products'.tr;
  static String get saleOrderTerms                => 'sale_order_terms'.tr;
  static String get saleOrderUntaxedAmount        => 'sale_order_untaxed_amount'.tr;
  static String get saleOrderTotal                => 'sale_order_total'.tr;
  static String get saleOrderFieldCustomer        => 'sale_order_field_customer'.tr;
  static String get saleOrderFieldOrderDate       => 'sale_order_field_order_date'.tr;
  static String get saleOrderFieldServiceLoc      => 'sale_order_field_service_loc'.tr;
  static String get saleOrderFieldPaymentTerms    => 'sale_order_field_payment_terms'.tr;
  static String get saleOrderFieldQuoteTmpl       => 'sale_order_field_quote_tmpl'.tr;
  static String get saleOrderOtherSalesperson     => 'sale_order_other_salesperson'.tr;
  static String get saleOrderOtherSalesTeam       => 'sale_order_other_sales_team'.tr;
  static String get saleOrderOtherCompany         => 'sale_order_other_company'.tr;
  static String get saleOrderOtherOnlineSig       => 'sale_order_other_online_sig'.tr;
  static String get saleOrderOtherOnlinePay       => 'sale_order_other_online_pay'.tr;
  static String get saleOrderOtherCustRef         => 'sale_order_other_cust_ref'.tr;
  static String get saleOrderOtherFiscalPos       => 'sale_order_other_fiscal_pos'.tr;
  static String get saleOrderOtherProject         => 'sale_order_other_project'.tr;
  static String get saleOrderOtherInvJournal      => 'sale_order_other_inv_journal'.tr;
  static String get saleOrderOtherInvStatus       => 'sale_order_other_inv_status'.tr;
  static String get saleOrderOtherWarehouse       => 'sale_order_other_warehouse'.tr;
  static String get saleOrderOtherIncoterm        => 'sale_order_other_incoterm'.tr;
  static String get saleOrderOtherIncotermLoc     => 'sale_order_other_incoterm_loc'.tr;
  static String get saleOrderOtherShipPolicy      => 'sale_order_other_ship_policy'.tr;
  static String get saleOrderOtherDeliveryDate    => 'sale_order_other_delivery_date'.tr;
  static String get saleOrderOtherDeliveryStatus  => 'sale_order_other_delivery_status'.tr;
  static String get saleOrderOtherSourceDoc       => 'sale_order_other_source_doc'.tr;
  static String get saleOrderOtherCampaign        => 'sale_order_other_campaign'.tr;
  static String get saleOrderOtherMedium          => 'sale_order_other_medium'.tr;
  static String get saleOrderOtherSource          => 'sale_order_other_source'.tr;
  static String get saleOrderSigSignedBy          => 'sale_order_sig_signed_by'.tr;
  static String get saleOrderSigSignedOn          => 'sale_order_sig_signed_on'.tr;
  static String get saleOrderSigSignature         => 'sale_order_sig_signature'.tr;
  static String get saleOrderSigNoSignature       => 'sale_order_sig_no_signature'.tr;
  static String get saleOrderSigLoadFailed        => 'sale_order_sig_load_failed'.tr;
  static String get saleOrderQuoteTemplate        => 'sale_order_quote_template'.tr;
  static String get saleOrderQuoteHeader          => 'sale_order_quote_header'.tr;
  static String get saleOrderQuoteFooter          => 'sale_order_quote_footer'.tr;
  static String get saleOrderInvoiceMethod        => 'sale_order_invoice_method'.tr;
  static String get saleOrderInvoiceRegular       => 'sale_order_invoice_regular'.tr;
  static String get saleOrderInvoiceRegularSub    => 'sale_order_invoice_regular_sub'.tr;
  static String get saleOrderInvoicePct           => 'sale_order_invoice_pct'.tr;
  static String get saleOrderInvoicePctSub        => 'sale_order_invoice_pct_sub'.tr;
  static String get saleOrderInvoiceFixed         => 'sale_order_invoice_fixed'.tr;
  static String get saleOrderInvoiceFixedSub      => 'sale_order_invoice_fixed_sub'.tr;
  static String get saleOrderInvoicePctLabel      => 'sale_order_invoice_pct_label'.tr;
  static String get saleOrderInvoiceFixedLabel    => 'sale_order_invoice_fixed_label'.tr;
  static String get saleOrderInvoiceCreate        => 'sale_order_invoice_create'.tr;
  static String get saleOrderInvoiceQueued        => 'sale_order_invoice_queued'.tr;
  static String get saleOrderStateQuotation       => 'sale_order_state_quotation'.tr;
  static String get saleOrderStateSent            => 'sale_order_state_sent'.tr;
  static String get saleOrderStateSale            => 'sale_order_state_sale'.tr;
  static String get saleOrderStateLocked          => 'sale_order_state_locked'.tr;
  static String get saleOrderStateCancelled       => 'sale_order_state_cancelled'.tr;
  static String get saleOrderSectionSales     => 'sale_order_section_sales'.tr;
  static String get saleOrderSectionInvoicing => 'sale_order_section_invoicing'.tr;
  static String get saleOrderSectionDelivery  => 'sale_order_section_delivery'.tr;
  static String get saleOrderSectionTracking  => 'sale_order_section_tracking'.tr;
  static String get saleOrderInvStatusUpselling => 'sale_order_inv_status_upselling'.tr;
  static String get saleOrderInvStatusInvoiced  => 'sale_order_inv_status_invoiced'.tr;
  static String get saleOrderInvStatusToInvoice => 'sale_order_inv_status_to_invoice'.tr;
  static String get saleOrderInvStatusNo        => 'sale_order_inv_status_no'.tr;
  static String get saleOrderShipAsSoon         => 'sale_order_ship_as_soon'.tr;
  static String get saleOrderShipWhenReady      => 'sale_order_ship_when_ready'.tr;
  static String get saleOrderDeliveryNot        => 'sale_order_delivery_not'.tr;
  static String get saleOrderDeliveryPartial    => 'sale_order_delivery_partial'.tr;
  static String get saleOrderDeliveryFull       => 'sale_order_delivery_full'.tr;
  static String get saleOrderExpectedPrefix     => 'sale_order_expected_prefix'.tr;



  // ── Delivery View ─────────────────────────────────────────────────────
  static String get deliveryStateDraft      => 'delivery_state_draft'.tr;
  static String get deliveryStateWaiting    => 'delivery_state_waiting'.tr;
  static String get deliveryStateReady      => 'delivery_state_ready'.tr;
  static String get deliveryStateDone       => 'delivery_state_done'.tr;
  static String get deliveryStateCancelled  => 'delivery_state_cancelled'.tr;
  static String get deliveryScheduled       => 'delivery_scheduled'.tr;
  static String get deliverySource          => 'delivery_source'.tr;
  static String get deliveryValidateBtn     => 'delivery_validate_btn'.tr;
  static String get deliveryAddr            => 'delivery_addr'.tr;
  static String get deliveryOpType          => 'delivery_op_type'.tr;
  static String get deliverySrcLocation     => 'delivery_src_location'.tr;
  static String get deliveryScheduledDate   => 'delivery_scheduled_date'.tr;
  static String get deliveryDeadline        => 'delivery_deadline'.tr;
  static String get deliverySourceDoc       => 'delivery_source_doc'.tr;
  static String get deliveryTabOperations   => 'delivery_tab_operations'.tr;
  static String get deliveryTabAdditional   => 'delivery_tab_additional'.tr;
  static String get deliveryTabNote         => 'delivery_tab_note'.tr;
  static String get deliveryColProduct      => 'delivery_col_product'.tr;
  static String get deliveryColDemand       => 'delivery_col_demand'.tr;
  static String get deliveryColQuantity     => 'delivery_col_quantity'.tr;
  static String get deliveryColUnit         => 'delivery_col_unit'.tr;
  static String get deliverySectionOtherInfo => 'delivery_section_other_info'.tr;
  static String get deliverySectionFsm      => 'delivery_section_fsm'.tr;
  static String get deliveryFieldShipping   => 'delivery_field_shipping_policy'.tr;
  static String get deliveryFieldResponsible => 'delivery_field_responsible'.tr;
  static String get deliveryFieldProcGroup  => 'delivery_field_proc_group'.tr;
  static String get deliveryFieldSaleOrder  => 'delivery_field_sale_order'.tr;
  static String get deliveryFieldCompany    => 'delivery_field_company'.tr;
  static String get deliveryFieldProject    => 'delivery_field_project'.tr;
  static String get deliveryFieldFsmOrder   => 'delivery_field_fsm_order'.tr;
  static String get deliveryShipAsSoon      => 'delivery_ship_as_soon'.tr;
  static String get deliveryShipWhenReady   => 'delivery_ship_when_ready'.tr;



  // ── Order Tab View ────────────────────────────────────────────────────
  static String get orderTabRetry            => 'order_tab_retry'.tr;
  static String get orderViewList            => 'order_view_list'.tr;
  static String get orderViewCalendar        => 'order_view_calendar'.tr;
  static String get orderViewKanban          => 'order_view_kanban'.tr;
  static String get orderListColScheduled    => 'order_list_col_scheduled'.tr;
  static String get orderListColName         => 'order_list_col_name'.tr;
  static String get orderListColLocation     => 'order_list_col_location'.tr;
  static String get orderListColAssigned     => 'order_list_col_assigned'.tr;
  static String get orderListColStage        => 'order_list_col_stage'.tr;
  static String get orderListColCompany      => 'order_list_col_company'.tr;
  static String get orderCalendarOrdersOn    => 'order_calendar_orders_on'.tr;
  static String get orderCalendarNoOrders    => 'order_calendar_no_orders'.tr;
  static String get orderSearchHint          => 'order_search_hint'.tr;
  static String get orderFilterTitle         => 'order_filter_title'.tr;
  static String get orderFilterMyOrders      => 'order_filter_my_orders'.tr;
  static String get orderFilterTodo          => 'order_filter_todo'.tr;
  static String get orderFilterUnassigned    => 'order_filter_unassigned'.tr;
  static String get orderFilterUnscheduled   => 'order_filter_unscheduled'.tr;
  static String get orderFilterDone          => 'order_filter_done'.tr;
  static String get orderFilterToday         => 'order_filter_today'.tr;
  static String get orderFilterFuture        => 'order_filter_future'.tr;
  static String get orderFilterDue7          => 'order_filter_due_7'.tr;
  static String get orderFilterDue30         => 'order_filter_due_30'.tr;
  static String get orderGroupByTitle        => 'order_groupby_title'.tr;
  static String get orderGroupByAssignedTo   => 'order_groupby_assigned_to'.tr;
  static String get orderKanbanDropHere      => 'order_kanban_drop_here'.tr;
  static String get orderKanbanNoOrders      => 'order_kanban_no_orders'.tr;
  static String get orderKanbanMoveFailed    => 'order_kanban_move_failed'.tr;
  static String get orderStageEdit           => 'order_stage_edit'.tr;
  static String get orderStageFold           => 'order_stage_fold'.tr;
  static String get orderStageUnfold         => 'order_stage_unfold'.tr;
  static String get orderStageDelete         => 'order_stage_delete'.tr;
  static String get orderStageDeleteConfirm  => 'order_stage_delete_confirm'.tr;
  static String get orderStageDeleteCannotUndo => 'order_stage_delete_cannot_undo'.tr;
  static String get orderStageSave           => 'order_stage_save'.tr;
  static String get orderStageDeleteBtn      => 'order_stage_delete_btn'.tr;
  static String get orderStageNameHint       => 'order_stage_name_hint'.tr;
  static String get orderStageAdd            => 'order_stage_add'.tr;
  static String get orderOfflineLabel        => 'order_offline_label'.tr;
  static String get orderKanbanDefaultCol => 'order_kanban_default_col'.tr;



  // ── Activities View ───────────────────────────────────────────────────
  static String get activitiesTitle          => 'activities_title'.tr;
  static String get activitiesNoFound        => 'activities_no_found'.tr;
  static String get activitiesTabAll         => 'activities_tab_all'.tr;
  static String get activitiesTabOverdue     => 'activities_tab_overdue'.tr;
  static String get activitiesTabToday       => 'activities_tab_today'.tr;
  static String get activitiesTabUpcoming    => 'activities_tab_upcoming'.tr;
  static String get activitiesDefaultTitle   => 'activities_default_title'.tr;
  static String get activitiesDefaultType    => 'activities_default_type'.tr;
  static String get activitiesUnassigned     => 'activities_unassigned'.tr;
  static String get activitiesNoDate         => 'activities_no_date'.tr;
  static String get activitiesAssigned       => 'activities_assigned'.tr;
  static String get activitiesTodayPrefix    => 'activities_today_prefix'.tr;
  static String get activitiesTomorrowPrefix => 'activities_tomorrow_prefix'.tr;
  static String get activitiesMarkDone       => 'activities_mark_done'.tr;
  static String get activitiesCancel         => 'activities_cancel'.tr;
  static String get activitiesMarkDoneSuccess  => 'activities_mark_done_success'.tr;
  static String get activitiesMarkDoneFailed   => 'activities_mark_done_failed'.tr;
  static String get activitiesCancelSuccess    => 'activities_cancel_success'.tr;
  static String get activitiesCancelFailed     => 'activities_cancel_failed'.tr;

}