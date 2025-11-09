class OtpScreenArgs {
  const OtpScreenArgs({
    required this.phoneNumber,
    required this.verificationId,
  });

  final String phoneNumber;
  final String verificationId;
}
