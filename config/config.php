<?php
/**
 * G-SMaRT Distribution System - configuration.
 * Set these to match your MySQL / MariaDB server (MySQL 5.5.3 or newer).
 * Environment variables (DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS) override them.
 *
 * The database below is Company 1. The platform (master) database is the same name followed by "_master"
 * (gsmart_distribution_master), and every company added by the Super Admin gets its own database
 * (gsmart_distribution_company_002, _003 ...).
 */
return [
    'db' => [
        'host'    => getenv('DB_HOST') ?: 'localhost',
        'port'    => getenv('DB_PORT') ?: '3306',
        'name'    => getenv('DB_NAME') ?: 'gsmart_distribution',
        'user'    => getenv('DB_USER') ?: 'root',
        'pass'    => getenv('DB_PASS') !== false ? (string)getenv('DB_PASS') : 'Jeglen',
        'charset' => 'utf8mb4',
    ],
    'app' => [
        'name'        => 'G-SMaRT Distribution System',
        'timezone'    => 'Asia/Manila',
        'currency'    => '₱',
        'debug'       => (getenv('APP_DEBUG') ?: '0') === '1',
        // folder (inside the project) where uploaded receipts are stored
        'upload_dir'  => __DIR__ . '/../storage/receipts',
    ],
];
