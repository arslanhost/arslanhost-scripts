# ArslanHOST Otomatik Kurulum Scriptleri

Bu repository, ArslanHOST müşterileri için otomatik sunucu kurulum scriptlerini içerir.

## 🚀 Hızlı Başlangıç

### Ubuntu 22.04 için n8n Kurulumu

```bash
curl -fsSL https://raw.githubusercontent.com/arslanhost/arslanhost-scripts/main/install-ubuntu-2204.sh | bash -c 'CF_API_TOKEN="YOUR_TOKEN" CF_ZONE_ID="YOUR_ZONE_ID" DOMAIN="arslanhost.com" ADMIN_EMAIL="admin@arslanhost.com" bash'
```

### CentOS 8 için n8n Kurulumu

```bash
curl -fsSL https://raw.githubusercontent.com/arslanhost/arslanhost-scripts/main/install-centos.sh | bash -c 'CF_API_TOKEN="YOUR_TOKEN" CF_ZONE_ID="YOUR_ZONE_ID" DOMAIN="arslanhost.com" ADMIN_EMAIL="admin@arslanhost.com" bash'
```

## 📋 Gereksinimler

### Cloudflare Ayarları
- **CF_API_TOKEN**: Cloudflare API token'ı (DNS edit yetkisi gerekli)
- **CF_ZONE_ID**: Cloudflare Zone ID
- **DOMAIN**: Ana domain (örn: arslanhost.com)
- **ADMIN_EMAIL**: SSL sertifika için e-posta adresi

### Sunucu Gereksinimleri
- **Ubuntu 22.04** veya **CentOS 8**
- **Minimum 2GB RAM**
- **Minimum 20GB Disk**
- **Root erişimi**

## 🔧 Kurulum Adımları

### 1. Cloudflare API Token Oluşturma
1. Cloudflare Dashboard'a giriş yapın
2. "My Profile" > "API Tokens" > "Create Token"
3. "Custom token" seçin
4. **Permissions**: Zone:Zone:Read, Zone:DNS:Edit
5. **Zone Resources**: Include:Specific zone:YOUR_ZONE_ID
6. Token'ı kopyalayın

### 2. Zone ID Bulma
1. Cloudflare Dashboard'da domain'inize gidin
2. Sağ tarafta "Zone ID" görünür
3. Bu ID'yi kopyalayın

### 3. Kurulum Komutu
```bash
# Ubuntu için
curl -fsSL https://raw.githubusercontent.com/arslanhost/arslanhost-scripts/main/install-ubuntu-2204.sh | bash -c 'CF_API_TOKEN="i9lP2M08ntTBfC0bjIYvGQdlngKPfnysr2Wji5zG" CF_ZONE_ID="0da2c757ba323937e90946c808ce8329" DOMAIN="arslanhost.com" ADMIN_EMAIL="admin@arslanhost.com" bash'
```

## 🎯 Kurulum Sonrası

Kurulum tamamlandıktan sonra:
- **n8n URL**: `https://n8n-XXXXXX.arslanhost.com`
- **Postgres Bilgileri**: Script çıktısında görüntülenir
- **SSL Sertifikası**: Otomatik olarak alınır
- **DNS Kaydı**: Otomatik olarak oluşturulur

## 📞 Destek

- **Web**: https://arslanhost.com
- **E-posta**: support@arslanhost.com
- **Telefon**: +90 XXX XXX XX XX

## 🔒 Güvenlik

- Tüm bağlantılar HTTPS ile şifrelenir
- SSL sertifikaları Let's Encrypt ile otomatik yenilenir
- Firewall kuralları otomatik yapılandırılır
- DNS kayıtları Cloudflare'de güvenli şekilde saklanır

## 📝 Lisans

Bu scriptler ArslanHOST tarafından geliştirilmiştir ve ticari kullanım için lisanslanmıştır.

---

**ArslanHOST - Güvenilir Bulut Altyapı Çözümleri**
