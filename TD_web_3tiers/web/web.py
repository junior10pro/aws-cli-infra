import os
import requests
from flask import Flask, request, render_template_string

app = Flask(__name__)

# DNS de l'ALB INTERNE injecté par user_data via la variable d'environnement
APP_API_URL = "http://{}/api/signup".format(os.environ["INTERNAL_ALB_DNS"])

FORM = """<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <title>Inscription</title>
  <style>
    body { font-family: sans-serif; max-width: 420px; margin: 60px auto; padding: 0 16px; }
    h1 { margin-bottom: 24px; }
    input, button { display: block; width: 100%; margin: 10px 0; padding: 10px;
                    box-sizing: border-box; font-size: 1rem; }
    button { background: #0072c6; color: #fff; border: none; cursor: pointer; }
    button:hover { background: #005fa3; }
    .success { color: #1a7f37; background: #dafbe1; padding: 10px; border-radius: 4px; }
    .error   { color: #cf222e; background: #ffebe9; padding: 10px; border-radius: 4px; }
  </style>
</head>
<body>
  <h1>Créer un compte</h1>
  {% if message %}
    <p class="{{ css }}">{{ message }}</p>
  {% endif %}
  <form method="post" action="/signup">
    <input name="full_name" placeholder="Nom complet">
    <input name="email"     type="email"    placeholder="Email"        required>
    <input name="password"  type="password" placeholder="Mot de passe" required>
    <button type="submit">S'inscrire</button>
  </form>
</body>
</html>"""


@app.get("/health")
def health():
    return "ok", 200


@app.get("/")
def form():
    return render_template_string(FORM, message=None, css="")


@app.post("/signup")
def signup():
    full_name = request.form.get("full_name", "").strip()
    email     = request.form.get("email", "").strip()
    password  = request.form.get("password", "")

    try:
        resp = requests.post(
            APP_API_URL,
            json={"email": email, "password": password, "full_name": full_name},
            timeout=5,
        )
    except requests.exceptions.RequestException:
        return render_template_string(FORM,
            message="Service d'inscription indisponible, réessayez.",
            css="error"), 503

    if resp.status_code == 201:
        return render_template_string(FORM,
            message="Compte créé avec succès pour {} !".format(email),
            css="success")

    if resp.status_code == 400:
        detail = resp.json().get("error", "Données invalides.")
        return render_template_string(FORM, message=detail, css="error"), 400

    if resp.status_code == 409:
        return render_template_string(FORM,
            message="Cet email est déjà utilisé.",
            css="error"), 409

    return render_template_string(FORM,
        message="Erreur inattendue ({}), réessayez.".format(resp.status_code),
        css="error"), 502


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
