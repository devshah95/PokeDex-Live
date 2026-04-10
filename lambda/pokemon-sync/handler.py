import json
import os
import boto3
import psycopg2
import urllib.request


def get_secret(secret_name, region='us-east-2'):
    """Retrieve a secret from AWS Secrets Manager"""
    client = boto3.client('secretsmanager', region_name=region)
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])


def fetch_pokemon(pokemon_id):
    """Fetch a single Pokémon from PokéAPI"""
    url = f"https://pokeapi.co/api/v2/pokemon/{pokemon_id}"
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read())


def get_stat(pokemon_data, stat_name):
    """Extract a specific stat from PokéAPI response"""
    for stat in pokemon_data['stats']:
        if stat['stat']['name'] == stat_name:
            return stat['base_stat']
    return 0


def sync_to_database(env):
    """Sync all 151 Pokémon to the database for a given environment"""
    secret = get_secret(f'pokeshop/{env}/pokemon-db')

    # Remove port from host if present
    host = secret['host'].split(':')[0]

    conn = psycopg2.connect(
        host=host,
        port=secret['port'],
        dbname=secret['dbname'],
        user=secret['username'],
        password=secret['password'],
        sslmode='require'
    )
    cursor = conn.cursor()
    updated = 0

    for pokemon_id in range(1, 152):
        try:
            data = fetch_pokemon(pokemon_id)

            cursor.execute("""
                INSERT INTO pokemon
                    (pokedex_id, name, primary_type, secondary_type,
                     hp, attack, defense, speed, special_attack, special_defense,
                     height, weight, base_experience, sprite_url)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (pokedex_id) DO UPDATE SET
                    name             = EXCLUDED.name,
                    primary_type     = EXCLUDED.primary_type,
                    secondary_type   = EXCLUDED.secondary_type,
                    hp               = EXCLUDED.hp,
                    attack           = EXCLUDED.attack,
                    defense          = EXCLUDED.defense,
                    speed            = EXCLUDED.speed,
                    special_attack   = EXCLUDED.special_attack,
                    special_defense  = EXCLUDED.special_defense,
                    height           = EXCLUDED.height,
                    weight           = EXCLUDED.weight,
                    base_experience  = EXCLUDED.base_experience,
                    sprite_url       = EXCLUDED.sprite_url
            """, (
                pokemon_id,
                data['name'],
                data['types'][0]['type']['name'],
                data['types'][1]['type']['name'] if len(data['types']) > 1 else None,
                get_stat(data, 'hp'),
                get_stat(data, 'attack'),
                get_stat(data, 'defense'),
                get_stat(data, 'speed'),
                get_stat(data, 'special-attack'),
                get_stat(data, 'special-defense'),
                data['height'],
                data['weight'],
                data.get('base_experience', 0),
                data['sprites']['front_default']
            ))
            updated += 1

        except Exception as e:
            print(f"Error syncing pokemon {pokemon_id}: {e}")

    conn.commit()
    cursor.close()
    conn.close()
    return updated


def handler(event, context):
    """Lambda entry point — runs nightly at 2 AM UTC via EventBridge"""
    print("Starting nightly Pokémon sync...")
    results = {}

    for env in ['dev', 'prod']:
        try:
            count = sync_to_database(env)
            results[env] = {'status': 'success', 'updated': count}
            print(f"  {env}: {count} Pokémon synced")
        except Exception as e:
            results[env] = {'status': 'error', 'message': str(e)}
            print(f"  {env}: ERROR — {e}")

    return {'statusCode': 200, 'body': json.dumps(results)}
