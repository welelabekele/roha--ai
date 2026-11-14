import asyncio
import json
import os
import unittest
from unittest.mock import AsyncMock, patch

os.environ['ROHA_API_TOKEN'] = 'test-token-' + 'x' * 40
from fastapi.testclient import TestClient
import httpx
import app


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.token = 'test-token-' + 'x' * 40
        app.TOKEN = self.token
        app.request_times.clear()
        self.client = TestClient(app.app)
        self.headers = {'Authorization': 'Bearer ' + self.token}

    def post(self, body):
        return self.client.post('/v1/turn', headers=self.headers, json=body)

    def test_health_is_not_readiness(self):
        self.assertEqual(self.client.get('/health').json()['model_readiness'], 'check_authenticated_status')

    def test_no_token(self):
        self.assertEqual(self.client.post('/v1/turn', json={'message': 'back'}).status_code, 401)

    def test_wrong_token(self):
        self.assertEqual(self.client.post('/v1/turn', headers={'Authorization': 'Bearer wrong'}, json={'message': 'back'}).status_code, 401)

    def test_multibyte_bad_token_does_not_crash(self):
        asyncio.run(self._bad_token())

    async def _bad_token(self):
        with self.assertRaises(app.HTTPException) as error:
            await app.authorize('Bearer ሙከራ')
        self.assertEqual(error.exception.status_code, 401)

    def test_unknown_field_rejected(self):
        self.assertEqual(self.post({'field': 'password', 'message': 'back'}).status_code, 422)

    def test_support_payload_rejected(self):
        self.assertEqual(self.post({'message': 'back', 'support': ['interpreter']}).status_code, 422)

    def test_command_does_not_call_model(self):
        with patch('app.ask_ollama', new_callable=AsyncMock) as model:
            data = self.post({'message': 'make the words bigger'}).json()
            self.assertEqual(data['action'], 'larger_text')
            self.assertFalse(data['executed'])
            model.assert_not_called()

    def test_submit_requests_review_only(self):
        data = self.post({'message': 'submit'}).json()
        self.assertEqual(data['action'], 'review')
        self.assertFalse(data['executed'])

    def test_negative_save_not_interpreted_as_save(self):
        self.assertIsNone(app.deterministic(app.Turn(message='do not save')))

    def test_language_aliases(self):
        for source, target in [('amh', 'am'), ('om-ET', 'om'), ('tir', 'ti'), ('en-US', 'en')]:
            self.assertEqual(app.Turn(language=source, message='test').language, target)

    def test_unsupported_language(self):
        self.assertEqual(self.post({'language': 'xx', 'message': 'test'}).status_code, 422)

    def test_oversize_message(self):
        self.assertEqual(self.post({'message': 'x' * 1501}).status_code, 422)

    def test_malicious_action_rejected(self):
        with self.assertRaises(ValueError):
            app.Proposal(action='execute_javascript', reply='run this')

    def test_choice_must_exist(self):
        with self.assertRaises(ValueError):
            app.check_proposal(app.Proposal(action='propose_answer', reply='OK', value='waive_all_requirements'), app.TASKS['registration']['idRoute'])

    def test_extra_model_fields_rejected(self):
        with self.assertRaises(ValueError):
            app.Proposal(action='back', reply='OK', url='https://example.com')

    def test_missing_answer_rejected(self):
        with self.assertRaises(ValueError):
            app.check_proposal(app.Proposal(action='propose_answer', reply='OK'), app.TASKS['registration']['name'])

    def test_answer_always_needs_confirmation(self):
        proposal = app.Proposal(action='propose_answer', reply='Use partner referral?', value='partner_referral')
        with patch('app.ask_ollama', new_callable=AsyncMock, return_value=proposal):
            data = self.post({'message': 'I have no document'}).json()
        self.assertTrue(data['requires_confirmation'])
        self.assertEqual(data['field'], 'idRoute')
        self.assertFalse(data['executed'])

    def test_model_failure_falls_back(self):
        with patch('app.ask_ollama', new_callable=AsyncMock, side_effect=ValueError('invalid JSON')):
            data = self.post({'language': 'am', 'message': 'help me please'}).json()
        self.assertEqual(data['source'], 'fallback')
        self.assertEqual(data['reply_language'], 'en')
        self.assertFalse(data['executed'])

    def test_global_budget(self):
        app.request_times.extend([app.time.monotonic()] * 30)
        self.assertEqual(self.post({'message': 'back'}).status_code, 429)

    def test_speech_needs_consent(self):
        response = self.client.post('/v1/transcribe', headers=self.headers, files={'audio': ('x.wav', b'audio')}, data={'consent': 'false'})
        self.assertEqual(response.status_code, 400)

    def test_speech_disabled_is_explicit(self):
        with patch.dict(os.environ, {'ROHA_STT_ENABLED': '0'}):
            response = self.client.post('/v1/transcribe', headers=self.headers, files={'audio': ('x.wav', b'audio')}, data={'consent': 'true'})
        self.assertEqual(response.status_code, 503)

    def test_real_ollama_request_contract(self):
        captured = []
        def transport(request):
            body = json.loads(request.content)
            captured.append(body)
            return httpx.Response(200, json={'message': {'content': json.dumps({'action': 'clarify', 'reply': 'Which document do you have?', 'value': None})}})
        original_client = httpx.AsyncClient
        with patch('app.httpx.AsyncClient', return_value=original_client(transport=httpx.MockTransport(transport))):
            result = asyncio.run(app.ask_ollama(app.Turn(message='help'), app.TASKS['registration']['idRoute']))
        self.assertEqual(result.action, 'clarify')
        self.assertFalse(captured[0]['think'])
        self.assertEqual(captured[0]['keep_alive'], 0)
        self.assertEqual(captured[0]['format']['additionalProperties'], False)
        self.assertNotIn('tools', captured[0])


if __name__ == '__main__':
    unittest.main()
