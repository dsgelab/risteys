from pandas import notna


def get_all_inclusions(endpoints):
    """Flatten the endpoint hierarchy with a map: endpoint -> all its descendants"""
    composite = endpoints[endpoints.INCLUDE.notna()]
    parents = composite.NAME
    children = composite.INCLUDE.str.split("|")

    # Build the graph of parent -> direct children
    graph = {}
    for p, c in zip(parents, children):
        graph[p] = set(c)

    # Build the map of parent -> all direct and indirect descendants
    res = {}
    cyclic = []
    for ee in endpoints.NAME:
        res[ee] = get_descendants(ee, graph, cyclic)

    return res


def get_descendants(name, graph, cyclic, acc=None):
    """Get all direct and indirect descendants of an endpoint"""
    # Initialize for first non tail-call
    if acc is None:
        acc = set()

    if name in cyclic:
        return graph.get(name, set())

    children = graph.get(name, set())
    children = children.difference(set([name]))  # case where an endpoint includes itself
    acc = acc.union(children)
    for child in children:
        acc = acc.union(get_descendants(child, graph, acc))
    return acc
