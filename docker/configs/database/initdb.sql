ALTER DATABASE `bluerange` CHARACTER SET 'utf8mb4' COLLATE  'utf8mb4_general_ci';

-- create grafana database
CREATE DATABASE IF NOT EXISTS grafana_bluerange;
CREATE USER 'grafana'@'%' IDENTIFIED BY '${GRAFANA_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON grafana_bluerange.* TO 'grafana'@'%';
