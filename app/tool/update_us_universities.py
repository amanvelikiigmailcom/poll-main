"""Build the offline US college directory from official NCES/IPEDS data.

Usage: python3 tool/update_us_universities.py [--archive /path/to/HD2024.zip]
Only active degree-granting 2-year/4-year institutions in US states,
DC and US territories are included. Separate IPEDS campuses retain their IDs.
"""
import argparse
import csv
import datetime
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

SOURCE_URL = 'https://nces.ed.gov/ipeds/datacenter/data/HD2024.zip'
STATES = dict(pair.split(':', 1) for pair in (
    'AL:Alabama|AK:Alaska|AZ:Arizona|AR:Arkansas|CA:California|CO:Colorado|'
    'CT:Connecticut|DE:Delaware|DC:District of Columbia|FL:Florida|GA:Georgia|'
    'HI:Hawaii|ID:Idaho|IL:Illinois|IN:Indiana|IA:Iowa|KS:Kansas|KY:Kentucky|'
    'LA:Louisiana|ME:Maine|MD:Maryland|MA:Massachusetts|MI:Michigan|MN:Minnesota|'
    'MS:Mississippi|MO:Missouri|MT:Montana|NE:Nebraska|NV:Nevada|NH:New Hampshire|'
    'NJ:New Jersey|NM:New Mexico|NY:New York|NC:North Carolina|ND:North Dakota|'
    'OH:Ohio|OK:Oklahoma|OR:Oregon|PA:Pennsylvania|RI:Rhode Island|SC:South Carolina|'
    'SD:South Dakota|TN:Tennessee|TX:Texas|UT:Utah|VT:Vermont|VA:Virginia|'
    'WA:Washington|WV:West Virginia|WI:Wisconsin|WY:Wyoming|PR:Puerto Rico|'
    'GU:Guam|VI:Virgin Islands|AS:American Samoa|MP:Northern Mariana Islands'
).split('|'))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    raw = args.archive.read_bytes() if args.archive else urllib.request.urlopen(SOURCE_URL, timeout=60).read()
    archive = zipfile.ZipFile(io.BytesIO(raw))
    csv_name = next(name for name in archive.namelist() if name.lower().endswith('.csv'))
    rows = csv.DictReader(io.StringIO(archive.read(csv_name).decode('utf-8-sig')))
    institutions = []
    for row in rows:
        if not (row['CYACTIVE'] == '1' and row['ACT'] in {'A', 'N', 'R'}
                and row['DEGGRANT'] == '1' and row['SECTOR'] in {'1', '2', '3', '4', '5', '6'}
                and row['STABBR'] in STATES and row['CLOSEDAT'].strip() in {'', '-2'}):
            continue
        institutions.append({
            'id': row['UNITID'], 'name': row['INSTNM'].strip(),
            'city': row['CITY'].strip(), 'state': row['STABBR'],
            'aliases': (row['IALIAS'].strip() + ' ' + STATES[row['STABBR']]).strip(),
        })
    institutions.sort(key=lambda item: (item['name'].casefold(), item['state'], item['id']))
    assert len(institutions) > 3500, 'Unexpectedly incomplete source data'
    assert len({item['id'] for item in institutions}) == len(institutions)
    data = {
        'source': 'NCES IPEDS HD2024 institution directory',
        'source_url': SOURCE_URL,
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'retrieved': datetime.date.today().isoformat(),
        'coverage': 'Active degree-granting 2-year and 4-year institutions in the 50 US states, DC and US territories, as reported in HD2024. Not a live directory.',
        'count': len(institutions), 'institutions': institutions,
    }
    destination = Path(__file__).resolve().parents[1] / 'assets/data/us_universities.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print(f'Wrote {len(institutions)} institutions to {destination}')

if __name__ == '__main__':
    main()
