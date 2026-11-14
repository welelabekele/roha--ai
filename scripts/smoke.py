"""Live Ollama/API smoke test. Run after scripts/start.sh in another terminal."""
from dotenv import dotenv_values
import httpx

token = dotenv_values('.env')['ROHA_API_TOKEN']
headers = {'Authorization': f'Bearer {token}'}
with httpx.Client(base_url='http://127.0.0.1:8000', headers=headers, timeout=150) as client:
    status = client.get('/v1/status'); status.raise_for_status()
    print('Model downloaded:', status.json()['llm_downloaded'])
    for language, message in [('en', 'I do not have any document. What can I do?'),
                              ('am', 'መታወቂያ የለኝም። ምን ላድርግ?')]:
        response = client.post('/v1/turn', json={'language': language, 'field': 'idRoute', 'message': message})
        response.raise_for_status()
        data = response.json()
        print(language, data)
        assert data['source'] == 'ollama', 'Model did not complete successfully; inspect server/Ollama logs.'
        assert data['executed'] is False
print('API/model protocol passed. Have native speakers assess meaning and language quality.')
