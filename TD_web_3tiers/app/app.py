import os
import re
import bcrypt
import psycopg2
from psycopg2 import errors as pg_errors
from flask import Flask, request, jsonify

app = Flask(__name__)

DB_CONFIG = {
    "host":     os.environ["DB_HOST"],
    "dbname":   os.environ["DB_NAME"],
    "user":     os.environ["DB_USER"],
    "password": os.environ["DB_PASSWORD"],
    "port":     5432,
}

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

# Base PostgreSQL partagee entre etudiants : on utilise notre PROPRE table
# (la table "users" existante appartient a d'autres TD et n'a pas de password_hash).
TABLE = "users_esso"

CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS {} (
    id            SERIAL PRIMARY KEY,
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(255),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
""".format(TABLE)


def init_db():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        with conn.cursor() as cur:
            cur.execute(CREATE_TABLE)
        conn.commit()
        conn.close()
    except Exception:
        pass


init_db()


@app.get("/health")
def health():
    return "ok", 200


@app.post("/api/signup")
def signup():
    data = request.get_json(force=True)

    email     = (data.get("email") or "").strip()
    password  = data.get("password") or ""
    full_name = (data.get("full_name") or "").strip() or None

    # Validation des champs
    if not email or not EMAIL_RE.match(email):
        return jsonify({"error": "Email invalide ou manquant"}), 400
    if not password:
        return jsonify({"error": "Mot de passe requis"}), 400

    # Hachage du mot de passe avec bcrypt (sel aléatoire inclus)
    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

    conn = None
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        with conn.cursor() as cur:
            # Requête paramétrée obligatoire (anti-injection SQL)
            cur.execute(
                "INSERT INTO " + TABLE + " (email, password_hash, full_name) VALUES (%s, %s, %s)",
                (email, password_hash, full_name),
            )
        conn.commit()
    except pg_errors.UniqueViolation:
        return jsonify({"error": "Email déjà utilisé"}), 409
    except Exception:
        return jsonify({"error": "Erreur serveur interne"}), 500
    finally:
        if conn:
            conn.close()

    return jsonify({"status": "created", "email": email}), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
