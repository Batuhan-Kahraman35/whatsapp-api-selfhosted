# Sorun giderme

[English](troubleshooting.md) | **Türkçe**

## 1. `pull access denied for atendai/evolution-api`

Proje image'larını taşıdı. Şunu kullanın:

```yaml
image: evoapicloud/evolution-api:v2.3.7
```

Sürümü sabitleyin. `latest` kullanmayın, çünkü her yükseltmede migration kontrolü gerekir (aşağıya bakın).

## 2. `The column wavoipToken does not exist` / instance oluşturulamıyor

**Neden:** Evolution API, PostgreSQL ve MySQL için ayrı Prisma migration setleri tutar. MySQL seti zaman
zaman geride kalır. Örneğin v2.2.3'te `Setting.wavoipToken` kolonu ve `Chat` tablosundaki bir unique index eksikti.
Bu yüzden instance oluşturmak tamamen bloke oluyordu.

**Tespit:** Canlı DB'de şemaya göre neyin eksik olduğunu listeleyin:

```bash
./scripts/check-migrations.sh
```

**Çözüm:** Çıktıdaki `ALTER TABLE` / `CREATE UNIQUE INDEX` komutlarını elle uygulayın (önce DB yedeği alın).

**Yükseltme tuzağı (P3009):** Sonraki bir sürüm, elle eklediğiniz kolonun resmi migration'ını getirdiğinde
Prisma `P3009` hatası verir (duplicate kolon / migration başarısız). O migration'ı uygulanmış olarak işaretleyin:

```bash
docker compose exec -T evolution-api npx prisma migrate resolve --applied <migration_adi> \
  --schema prisma/mysql-schema.prisma
docker compose up -d --force-recreate evolution-api
```

Migration adı container loglarında yazar.

## 3. QR kod gelmiyor

**Belirti:** `GET /instance/connect/<ad>` sürekli `{"count":0}` döner, instance'ın oturum dizini boş kalır.

**Neden:** Eski image'lardaki Baileys sürümünü WhatsApp reddediyor (v2.2.3'te görüldü).

**Çözüm:** Image'ı yükseltin (v2.3.7 çalışıyor). Yeni sürümlerde `GET /` yanıtı `whatsappWebVersion` alanını
da döndürür. QR sorunlarında önce bu alana bakın.

## 4. Container MariaDB'ye bağlanamıyor

- `bind-address` içinde `172.17.0.1` (sunucunun `docker0` adresi) olmalı. DB kullanıcısı `'kullanici'@'%'`
  olmalı ya da en azından Docker subnet'ini kapsamalı.
- Sunucu firewall'u açıksa 3306'ya yalnızca Docker subnet'lerinden izin verin:

  ```bash
  iptables -I INPUT -i docker0 -p tcp --dport 3306 -j ACCEPT
  iptables -I INPUT -i br-+ -p tcp --dport 3306 -j ACCEPT
  ```

- Container ağından test edin:

  ```bash
  docker run --rm --network evolution-api_evolution-net alpine \
    sh -c "apk add -q mariadb-client && mariadb -h 172.17.0.1 -u evolution_user -p -e 'SELECT 1'"
  ```

## 5. `.env` değişiklikleri etki etmiyor

`docker compose restart` eski ortam değişkenlerini korur. Container'ı yeniden oluşturun:

```bash
docker compose up -d --force-recreate evolution-api
```

## 6. Manager arayüzü: WebSocket hatası ya da sayfa açılıyor ama boş kalıyor

- nginx'te `Upgrade` / `Connection "upgrade"` başlıklarının olduğundan emin olun.
- Plesk'te **Proxy modu** kapalı olmalı. Açıksa istek Apache'den geçer ve WebSocket upgrade kaybolur.
- Cloudflare'da WebSockets açık olmalı (Network sekmesi, varsayılan olarak açık).

## 7. nginx/markalama değişiklikleri görünmüyor

Host Cloudflare'da proxied ise (turuncu bulut) PNG ve JS bundle gibi statik dosyalar kenar sunucularda cache'lenir.

- Her nginx değişikliğinden sonra purge yapın. Bundle adı her sürümde değiştiği için yükseltmelerden sonra tekrarlanır.
- Kalıcı çözüm: bu hostname için "Bypass cache" Cache Rule'u ekleyin.
- Origin'i Cloudflare'ı atlayarak doğrudan test edin:

  ```bash
  curl -k --resolve whatsapp.example.com:443:<SUNUCU_IP> https://whatsapp.example.com/
  ```

## 8. Markalama: logo değişti ama tarayıcıda kırık görsel çıkıyor

nginx MIME türünü **URI'daki uzantıya** göre belirler. Bir `.png` yolunu SVG'ye `alias` ederseniz dosya
`image/png` olarak servis edilir ve tarayıcı onu render etmez. `default_type` tek başına yetmez,
boş bir `types { }` bloğu şarttır:

```nginx
location = /assets/images/evolution-logo.png {
    alias /path/to/branding/my-logo-white.svg;
    types { }
    default_type image/svg+xml;
}
```

Ayrıca `sub_filter` sıkıştırılmamış upstream yanıtı ister (`proxy_set_header Accept-Encoding "";`) ve çok büyük
JS bundle'larında bazı eşleşmeleri kaçırabilir. Kritik dosyalarda `location` + `alias` tercih edin.
