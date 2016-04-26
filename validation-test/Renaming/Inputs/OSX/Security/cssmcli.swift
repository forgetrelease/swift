
struct cssm_spi_cl_funcs {
  var CertCreateTemplate: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafePointer<cssm_field>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CertGetAllTemplateFields: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!
  var CertSign: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CertVerify: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32) -> CSSM_RETURN)!
  var CertVerifyWithKey: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!) -> CSSM_RETURN)!
  var CertGetFirstFieldValue: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CertGetNextFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CertAbortQuery: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!
  var CertGetKeyInfo: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_key>?>!) -> CSSM_RETURN)!
  var CertGetAllFields: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!
  var FreeFields: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!
  var FreeFieldValue: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<CSSM_OID>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CertCache: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, CSSM_HANDLE_PTR!) -> CSSM_RETURN)!
  var CertGetFirstCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CertGetNextCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CertAbortCache: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!
  var CertGroupToSignedBundle: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<CSSM_CERTGROUP>!, UnsafePointer<cssm_cert_bundle_header>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CertGroupFromVerifiedBundle: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_cert_bundle>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<CSSM_CERTGROUP_PTR?>!) -> CSSM_RETURN)!
  var CertDescribeFormat: (@convention(c) (CSSM_CL_HANDLE, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<CSSM_OID_PTR?>!) -> CSSM_RETURN)!
  var CrlCreateTemplate: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafePointer<cssm_field>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CrlSetFields: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafePointer<cssm_field>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CrlAddCert: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, uint32, UnsafePointer<cssm_field>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CrlRemoveCert: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CrlSign: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CrlVerify: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32) -> CSSM_RETURN)!
  var CrlVerifyWithKey: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!) -> CSSM_RETURN)!
  var IsCertInCrl: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<CSSM_BOOL>!) -> CSSM_RETURN)!
  var CrlGetFirstFieldValue: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CrlGetNextFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CrlAbortQuery: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!
  var CrlGetAllFields: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!
  var CrlCache: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, CSSM_HANDLE_PTR!) -> CSSM_RETURN)!
  var IsCertInCachedCrl: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, CSSM_HANDLE, UnsafeMutablePointer<CSSM_BOOL>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!
  var CrlGetFirstCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CrlGetNextCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!
  var CrlGetAllCachedRecordFields: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!
  var CrlAbortCache: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!
  var CrlDescribeFormat: (@convention(c) (CSSM_CL_HANDLE, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<CSSM_OID_PTR?>!) -> CSSM_RETURN)!
  var PassThrough: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, uint32, UnsafePointer<Void>!, UnsafeMutablePointer<UnsafeMutablePointer<Void>?>!) -> CSSM_RETURN)!
  init()
  init(CertCreateTemplate CertCreateTemplate: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafePointer<cssm_field>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CertGetAllTemplateFields CertGetAllTemplateFields: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!, CertSign CertSign: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CertVerify CertVerify: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32) -> CSSM_RETURN)!, CertVerifyWithKey CertVerifyWithKey: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!) -> CSSM_RETURN)!, CertGetFirstFieldValue CertGetFirstFieldValue: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CertGetNextFieldValue CertGetNextFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CertAbortQuery CertAbortQuery: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!, CertGetKeyInfo CertGetKeyInfo: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_key>?>!) -> CSSM_RETURN)!, CertGetAllFields CertGetAllFields: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!, FreeFields FreeFields: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!, FreeFieldValue FreeFieldValue: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<CSSM_OID>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CertCache CertCache: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, CSSM_HANDLE_PTR!) -> CSSM_RETURN)!, CertGetFirstCachedFieldValue CertGetFirstCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CertGetNextCachedFieldValue CertGetNextCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CertAbortCache CertAbortCache: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!, CertGroupToSignedBundle CertGroupToSignedBundle: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<CSSM_CERTGROUP>!, UnsafePointer<cssm_cert_bundle_header>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CertGroupFromVerifiedBundle CertGroupFromVerifiedBundle: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_cert_bundle>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<CSSM_CERTGROUP_PTR?>!) -> CSSM_RETURN)!, CertDescribeFormat CertDescribeFormat: (@convention(c) (CSSM_CL_HANDLE, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<CSSM_OID_PTR?>!) -> CSSM_RETURN)!, CrlCreateTemplate CrlCreateTemplate: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafePointer<cssm_field>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CrlSetFields CrlSetFields: (@convention(c) (CSSM_CL_HANDLE, uint32, UnsafePointer<cssm_field>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CrlAddCert CrlAddCert: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, uint32, UnsafePointer<cssm_field>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CrlRemoveCert CrlRemoveCert: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CrlSign CrlSign: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CrlVerify CrlVerify: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafePointer<cssm_field>!, uint32) -> CSSM_RETURN)!, CrlVerifyWithKey CrlVerifyWithKey: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, UnsafePointer<cssm_data>!) -> CSSM_RETURN)!, IsCertInCrl IsCertInCrl: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<cssm_data>!, UnsafeMutablePointer<CSSM_BOOL>!) -> CSSM_RETURN)!, CrlGetFirstFieldValue CrlGetFirstFieldValue: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CrlGetNextFieldValue CrlGetNextFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CrlAbortQuery CrlAbortQuery: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!, CrlGetAllFields CrlGetAllFields: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!, CrlCache CrlCache: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, CSSM_HANDLE_PTR!) -> CSSM_RETURN)!, IsCertInCachedCrl IsCertInCachedCrl: (@convention(c) (CSSM_CL_HANDLE, UnsafePointer<cssm_data>!, CSSM_HANDLE, UnsafeMutablePointer<CSSM_BOOL>!, UnsafeMutablePointer<cssm_data>!) -> CSSM_RETURN)!, CrlGetFirstCachedFieldValue CrlGetFirstCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafePointer<cssm_data>!, UnsafePointer<CSSM_OID>!, CSSM_HANDLE_PTR!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CrlGetNextCachedFieldValue CrlGetNextCachedFieldValue: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafeMutablePointer<UnsafeMutablePointer<cssm_data>?>!) -> CSSM_RETURN)!, CrlGetAllCachedRecordFields CrlGetAllCachedRecordFields: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE, UnsafePointer<cssm_data>!, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<UnsafeMutablePointer<cssm_field>?>!) -> CSSM_RETURN)!, CrlAbortCache CrlAbortCache: (@convention(c) (CSSM_CL_HANDLE, CSSM_HANDLE) -> CSSM_RETURN)!, CrlDescribeFormat CrlDescribeFormat: (@convention(c) (CSSM_CL_HANDLE, UnsafeMutablePointer<uint32>!, UnsafeMutablePointer<CSSM_OID_PTR?>!) -> CSSM_RETURN)!, PassThrough PassThrough: (@convention(c) (CSSM_CL_HANDLE, CSSM_CC_HANDLE, uint32, UnsafePointer<Void>!, UnsafeMutablePointer<UnsafeMutablePointer<Void>?>!) -> CSSM_RETURN)!)
}
