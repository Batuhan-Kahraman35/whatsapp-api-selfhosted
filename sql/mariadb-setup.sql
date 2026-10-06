-- Database: MariaDB / MySQL on the host (run as root)
-- Evolution API creates its own tables via Prisma migrations on first start.

CREATE DATABASE IF NOT EXISTS `evolution`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- '%' is required because the container connects from the Docker bridge subnet,
-- not from localhost. MariaDB is still not reachable from outside
-- (bind-address is limited to 127.0.0.1 and 172.17.0.1, see README).
CREATE USER IF NOT EXISTS 'evolution_user'@'%' IDENTIFIED BY 'CHANGE_ME';

GRANT ALL PRIVILEGES ON `evolution`.* TO 'evolution_user'@'%';
FLUSH PRIVILEGES;
