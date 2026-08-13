/**
 * Cryptographic helpers for the questionnaire OTP/token flow.
 * Kept separate from the controllers so the hashing/randomness approach
 * has a single, easily-reviewed home.
 */
public with sharing class OtpUtil {

    public static String generateNumericOtp(Integer numDigits) {
        String digits = '';
        for (Integer i = 0; i < numDigits; i++) {
            digits += String.valueOf(Crypto.getRandomInteger() & 2147483647).right(1);
        }
        return digits;
    }

    public static String generateToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }

    public static String generateSalt() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    }

    public static String hash(String value) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(value)));
    }
}
