class FsmLocationDialogModel {
  const FsmLocationDialogModel({
    required this.phone,
    required this.mobile,
    required this.street,
    required this.street2,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
  });

  final String phone;
  final String mobile;
  final String street;
  final String street2;
  final String city;
  final String state;
  final String zip;
  final String country;

  factory FsmLocationDialogModel.empty() => const FsmLocationDialogModel(
        phone: '',
        mobile: '',
        street: '',
        street2: '',
        city: '',
        state: '',
        zip: '',
        country: '',
      );
}
