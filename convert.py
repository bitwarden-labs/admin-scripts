import csv
import json
import io

INPUT_FILE = "truekey-export.csv"
OUTPUT_FILE = "bitwarden_import.json"

KNOWN_KINDS = {"login", "note", "cc", "passport", "drivers", "membership"}


def preprocess(input_file):
    """Stitch broken multiline rows back together"""
    with open(input_file, encoding='utf-8') as f:
        lines = f.readlines()

    fixed = []
    for line in lines:
        kind = line.split(",")[0].strip().lower()
        if kind in KNOWN_KINDS or kind == "kind":
            fixed.append(line.rstrip("\n"))
        else:
            if fixed:
                fixed[-1] += " " + line.rstrip("\n")
    return "\n".join(fixed)


def parse_expiry(date_str):
    """Try to extract month and year from expiry date strings"""
    if not date_str:
        return None, None
    parts = date_str.replace("-", "/").split("/")
    if len(parts) == 2:
        return parts[0], parts[1]
    elif len(parts) == 3:
        if len(parts[0]) == 4:
            return parts[1], parts[0]  # YYYY/MM/DD
        else:
            return parts[0], parts[2]  # MM/DD/YYYY
    return None, None


def convert(input_file, output_file):
    items = []

    preprocessed = preprocess(input_file)
    reader = csv.DictReader(io.StringIO(preprocessed))

    for row in reader:
        kind = row.get("kind", "").lower().replace(" ", "")
        favorite = (row.get("favorite") or "").lower() in ("true", "1", "yes")

        notes_parts = [row.get("note") or "", row.get(
            "memo") or "", row.get("content") or ""]
        notes = " | ".join(p for p in notes_parts if p and p.strip())

        if kind == "note":
            items.append({
                "type": 2,
                "name": row.get("name", ""),
                "notes": notes,
                "favorite": favorite,
                "reprompt": 0,
                "secureNote": {"type": 0}
            })

        elif kind == "cc":
            exp_month, exp_year = parse_expiry(
                row.get("expirationDate") or row.get("expiryDate") or ""
            )
            items.append({
                "type": 3,
                "name": row.get("name", ""),
                "notes": notes,
                "favorite": favorite,
                "reprompt": 0,
                "card": {
                    "cardholderName": row.get("cardholder", ""),
                    "brand": row.get("type", ""),
                    "number": row.get("number", ""),
                    "expMonth": exp_month,
                    "expYear": exp_year,
                    "code": None
                }
            })

        elif kind in ("drivers", "passport"):
            street = " ".join(filter(None, [
                row.get("streetNumber", ""),
                row.get("street", "")
            ]))
            items.append({
                "type": 4,
                "name": row.get("name", ""),
                "notes": notes,
                "favorite": favorite,
                "reprompt": 0,
                "identity": {
                    "title": row.get("title", ""),
                    "firstName": row.get("firstName", ""),
                    "lastName": row.get("lastName", ""),
                    "company": row.get("company", ""),
                    "email": row.get("email", ""),
                    "phone": row.get("phoneNumber") or row.get("telephone") or "",
                    "address1": street,
                    "city": row.get("city", ""),
                    "state": row.get("state", ""),
                    "postalCode": row.get("zipCode", ""),
                    "country": row.get("country", ""),
                    "username": None
                }
            })

        elif kind == "membership":
            membership_parts = [
                f"Member ID: {row.get('member_id', '')}",
                f"Member Since: {row.get('memberSince', '')}",
                f"Phone: {row.get('phoneNumber') or row.get('telephone') or ''}",
                f"Website: {row.get('url') or row.get('website') or ''}",
            ]
            membership_notes = "\n".join(
                p for p in membership_parts if p.split(": ")[1].strip()
            )
            if notes:
                membership_notes = membership_notes + "\n" + \
                    notes if membership_notes else notes
            items.append({
                "type": 2,
                "name": row.get("name", ""),
                "notes": membership_notes,
                "favorite": favorite,
                "reprompt": 0,
                "secureNote": {"type": 0}
            })

        else:
            # Login (default)
            uri = row.get("url") or row.get("website") or ""
            uris = [{"match": None, "uri": uri}] if uri else []
            items.append({
                "type": 1,
                "name": row.get("name", ""),
                "notes": notes,
                "favorite": favorite,
                "reprompt": 0,
                "login": {
                    "username": row.get("login", ""),
                    "password": row.get("password", ""),
                    "uris": uris,
                    "totp": None
                }
            })

    output = {
        "encrypted": False,
        "folders": [],
        "items": items
    }

    with open(output_file, "w", encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    type_counts = {1: 0, 2: 0, 3: 0, 4: 0}
    for item in items:
        type_counts[item["type"]] = type_counts.get(item["type"], 0) + 1

    print(f"Done! {len(items)} entries written to {output_file}")
    print(f"  Logins:       {type_counts[1]}")
    print(f"  Secure Notes: {type_counts[2]}  (includes notes + memberships)")
    print(f"  Cards:        {type_counts[3]}")
    print(f"  Identities:   {type_counts[4]}  (includes drivers + passports)")


convert(INPUT_FILE, OUTPUT_FILE)
