import json
from os import getenv

from starlette.applications import Starlette
from starlette.responses import HTMLResponse
from starlette.staticfiles import StaticFiles
from starlette.websockets import WebSocketDisconnect


PORT = getenv('PORT', 8000)


PAST_SEARCHES = {
    'title': 'Past Searches',
    'items': {
        'CDV',
        'angina',
        'R19',
    },
    'search': lambda x: x,
}


with open('data/icd.json') as f:
    ICD_CODES = {
        'title': 'ICD Codes',
        'items': json.load(f),
        'search': lambda x: x[0] + " – " + x[1],
    }
with open('data/endpoints.json') as f:
    ENDPOINTS = {
        'title': 'Endpoints',
        'items': json.load(f),
        'search': lambda x: x[1],
    }

app = Starlette(template_directory='templates')
app.debug = True
app.mount('/dist', StaticFiles(directory='dist'), name='dist')


@app.route('/')
async def homepage(request):
    template = app.get_template('web_client.html')
    content = template.render(request=request, port=PORT)
    return HTMLResponse(content)


@app.websocket_route('/ws')
async def websocket_endpoint(websocket):
    await websocket.accept()

    while True:
        # Receive query
        try:
            txt = await websocket.receive_text()
        except WebSocketDisconnect as exc:
            print(f'Connection closed by client: {exc}')
            break

        # Send results
        items = search_state(txt)
        await websocket.send_json(items)

    await websocket.close()


def search_state(query):
    res = [
        PAST_SEARCHES,
        ENDPOINTS,
        ICD_CODES,
    ]
    res = map(lambda d: filter_data(query, d), res)
    res = filter(lambda d: len(d['items']) > 0, res)
    res = list(res)
    return res


def filter_data(query, data):
    searchfn = data['search']
    searchables = map(searchfn, data['items'])

    res = map(lambda item: search(item, query), searchables)
    res = filter(lambda x: x is not None, res)
    res = list(res)[:5]
    res = {
        'title': data['title'],
        'items': res
    }
    return res


def search(item, query):
    pos = item.lower().find(query.lower())
    size = len(query)
    if pos == -1:
        return None
    else:
        res = item[:pos] + '<span class="highlight">' + item[pos : pos + size] + '</span>' + item[pos + size:]
        return res

    # if query == "" or query.lower() in item.lower():
    #     return "<span>" + item
    # else:
    #     return None


def search_endpoints(query, max_items=5):
    def mfilter(item):
        searchfn = ENDPOINTS['search']
        searchable = searchfn(item)
        if query == "" or query.lower() in searchable.lower():
            return searchable
        else:
            return None
    filtered = map(mfilter, ENDPOINTS)
    filtered = filter(lambda x: x is not None, filtered)
    return list(filtered)[:max_items]


if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='127.0.0.1', port=PORT)
