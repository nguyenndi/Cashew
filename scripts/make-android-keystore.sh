#!/usr/bin/env bash
# Tạo khóa ký APK cho workflow .github/workflows/build-apk.yml (chạy MỘT lần, trên máy của bạn).
#
# Cách dùng:
#   bash scripts/make-android-keystore.sh [đường-dẫn-file.jks]
#
# Mặc định file được tạo ở ~/cashew-release.jks (NGOÀI repo, tuyệt đối không commit file này
# vì kho là công khai). Script in ra 4 giá trị để dán vào
#   GitHub > Settings > Secrets and variables > Actions > New repository secret
# Hãy sao lưu file .jks và mật khẩu: mất khóa thì không cập nhật đè được app đã cài.
set -euo pipefail

OUT="${1:-$HOME/cashew-release.jks}"
ALIAS="cashew"

if [ -e "$OUT" ]; then
  echo "File $OUT đã tồn tại, không ghi đè. Hãy chọn đường dẫn khác hoặc xóa file cũ." >&2
  exit 1
fi
for tool in keytool openssl base64; do
  command -v "$tool" > /dev/null || { echo "Thiếu lệnh '$tool' (cần cài JDK/OpenSSL)." >&2; exit 1; }
done

PASSWORD="$(openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 24)"

keytool -genkeypair \
  -keystore "$OUT" -storetype JKS \
  -storepass "$PASSWORD" -keypass "$PASSWORD" \
  -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
  -dname "CN=Cashew, O=Cashew, C=VN" > /dev/null 2>&1

# base64 không xuống dòng (GNU: -w0, macOS: không có -w nên mặc định đã một dòng)
if base64 -w0 "$OUT" > /dev/null 2>&1; then
  B64="$(base64 -w0 "$OUT")"
else
  B64="$(base64 < "$OUT" | tr -d '\n')"
fi
B64_FILE="${OUT}.base64.txt"
printf '%s' "$B64" > "$B64_FILE"
chmod 600 "$OUT" "$B64_FILE" 2>/dev/null || true

cat <<EOF

Đã tạo khóa: $OUT
Đã lưu bản base64: $B64_FILE   (mở file này, copy toàn bộ nội dung cho secret đầu tiên)

Tạo 4 secret trong repo (tên phải đúng):

  ANDROID_KEYSTORE_BASE64     = nội dung file $B64_FILE
  ANDROID_KEYSTORE_PASSWORD   = $PASSWORD
  ANDROID_KEY_ALIAS           = $ALIAS
  ANDROID_KEY_PASSWORD        = $PASSWORD

Nếu máy có GitHub CLI (gh) đã đăng nhập, có thể chạy thay cho việc dán tay:

  gh secret set ANDROID_KEYSTORE_BASE64   --repo nguyenndi/Cashew < "$B64_FILE"
  gh secret set ANDROID_KEYSTORE_PASSWORD --repo nguyenndi/Cashew --body "$PASSWORD"
  gh secret set ANDROID_KEY_ALIAS         --repo nguyenndi/Cashew --body "$ALIAS"
  gh secret set ANDROID_KEY_PASSWORD      --repo nguyenndi/Cashew --body "$PASSWORD"

Xong thì xóa $B64_FILE; giữ lại $OUT cùng mật khẩu ở nơi an toàn (KHÔNG commit vào repo).
EOF
