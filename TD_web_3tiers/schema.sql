-- Schema de la table applicative.
-- IMPORTANT : la base RDS "mydb" est PARTAGEE entre plusieurs etudiants et
-- contient deja une table "users" (sans colonne password_hash) appartenant a
-- d'autres TD. On utilise donc notre PROPRE table "users_esso" pour ne pas
-- entrer en conflit. Cette table est creee automatiquement au demarrage de
-- l'API (fonction init_db dans app/app.py) ; ce fichier sert de reference /
-- creation manuelle.

CREATE TABLE IF NOT EXISTS users_esso (
    id            SERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(255),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
