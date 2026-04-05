package admin

import "testing"

func TestAdminLoginPasswordOK_uppercaseMD5Hex(t *testing.T) {
	stored := "e00cf25ad42683b3df678c61f42c6bda"
	upper := "E00CF25AD42683B3DF678C61F42C6BDA"
	if !adminLoginPasswordOK(stored, upper) {
		t.Fatalf("expected uppercase client MD5 to match lowercase stored hash")
	}
}

func TestAdminLoginPasswordOK_plainPasswordVsInitStyleStored(t *testing.T) {
	stored := "e00cf25ad42683b3df678c61f42c6bda" // md5("admin1")
	if !adminLoginPasswordOK(stored, "admin1") {
		t.Fatalf("expected plain password to match init-style stored md5")
	}
}
