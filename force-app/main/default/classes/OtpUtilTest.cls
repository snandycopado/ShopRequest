@IsTest
private class OtpUtilTest {

    @IsTest
    static void generatesNumericOtpOfRequestedLength() {
        String otp = OtpUtil.generateNumericOtp(6);
        System.assertEquals(6, otp.length(), 'OTP should be exactly 6 characters');
        System.assert(otp.isNumeric(), 'OTP should contain only digits');
    }

    @IsTest
    static void generatesDistinctTokensAndSalts() {
        String tokenOne = OtpUtil.generateToken();
        String tokenTwo = OtpUtil.generateToken();
        System.assertNotEquals(tokenOne, tokenTwo, 'Tokens should be random/unique');
        System.assertEquals(64, tokenOne.length(), '32 random bytes should hex-encode to 64 characters');

        String saltOne = OtpUtil.generateSalt();
        String saltTwo = OtpUtil.generateSalt();
        System.assertNotEquals(saltOne, saltTwo, 'Salts should be random/unique');
    }

    @IsTest
    static void hashIsDeterministicForSameInputAndDiffersForDifferentInput() {
        String hashOne = OtpUtil.hash('123456' + 'saltvalue');
        String hashTwo = OtpUtil.hash('123456' + 'saltvalue');
        String hashThree = OtpUtil.hash('654321' + 'saltvalue');

        System.assertEquals(hashOne, hashTwo, 'Same input should always hash the same way');
        System.assertNotEquals(hashOne, hashThree, 'Different input should hash differently');
    }
}
