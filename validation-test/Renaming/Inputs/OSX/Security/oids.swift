
typealias DERByte = UInt8
typealias DERSize = Int
struct DERItem {
  var data: UnsafeMutablePointer<DERByte>!
  var length: DERSize
  init()
  init(data data: UnsafeMutablePointer<DERByte>!, length length: DERSize)
}
let oidRsa: DERItem
let oidMd2Rsa: DERItem
let oidMd4Rsa: DERItem
let oidMd5Rsa: DERItem
let oidSha1Rsa: DERItem
let oidSha256Rsa: DERItem
let oidSha384Rsa: DERItem
let oidSha512Rsa: DERItem
let oidSha224Rsa: DERItem
let oidEcPubKey: DERItem
let oidSha1Ecdsa: DERItem
let oidSha224Ecdsa: DERItem
let oidSha256Ecdsa: DERItem
let oidSha384Ecdsa: DERItem
let oidSha512Ecdsa: DERItem
let oidSha1Dsa: DERItem
let oidMd2: DERItem
let oidMd4: DERItem
let oidMd5: DERItem
let oidSha1: DERItem
let oidSha1DsaOIW: DERItem
let oidSha1DsaCommonOIW: DERItem
let oidSha1RsaOIW: DERItem
let oidSha256: DERItem
let oidSha384: DERItem
let oidSha512: DERItem
let oidSha224: DERItem
let oidFee: DERItem
let oidMd5Fee: DERItem
let oidSha1Fee: DERItem
let oidSubjectKeyIdentifier: DERItem
let oidKeyUsage: DERItem
let oidPrivateKeyUsagePeriod: DERItem
let oidSubjectAltName: DERItem
let oidIssuerAltName: DERItem
let oidBasicConstraints: DERItem
let oidNameConstraints: DERItem
let oidCrlDistributionPoints: DERItem
let oidCertificatePolicies: DERItem
let oidAnyPolicy: DERItem
let oidPolicyMappings: DERItem
let oidAuthorityKeyIdentifier: DERItem
let oidPolicyConstraints: DERItem
let oidExtendedKeyUsage: DERItem
let oidAnyExtendedKeyUsage: DERItem
let oidInhibitAnyPolicy: DERItem
let oidAuthorityInfoAccess: DERItem
let oidSubjectInfoAccess: DERItem
let oidAdOCSP: DERItem
let oidAdCAIssuer: DERItem
let oidNetscapeCertType: DERItem
let oidEntrustVersInfo: DERItem
let oidMSNTPrincipalName: DERItem
let oidQtCps: DERItem
let oidQtUNotice: DERItem
let oidCommonName: DERItem
let oidCountryName: DERItem
let oidLocalityName: DERItem
let oidStateOrProvinceName: DERItem
let oidOrganizationName: DERItem
let oidOrganizationalUnitName: DERItem
let oidDescription: DERItem
let oidEmailAddress: DERItem
let oidFriendlyName: DERItem
let oidLocalKeyId: DERItem
let oidExtendedKeyUsageServerAuth: DERItem
let oidExtendedKeyUsageClientAuth: DERItem
let oidExtendedKeyUsageCodeSigning: DERItem
let oidExtendedKeyUsageEmailProtection: DERItem
let oidExtendedKeyUsageTimeStamping: DERItem
let oidExtendedKeyUsageOCSPSigning: DERItem
let oidExtendedKeyUsageIPSec: DERItem
let oidExtendedKeyUsageMicrosoftSGC: DERItem
let oidExtendedKeyUsageNetscapeSGC: DERItem
let oidGoogleEmbeddedSignedCertificateTimestamp: DERItem
let oidGoogleOCSPSignedCertificateTimestamp: DERItem
