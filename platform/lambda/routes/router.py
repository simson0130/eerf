"""
EERF API Router — Path-based routing with regex patterns.

Usage:
    router = Router()
    router.add("GET", "/services", handler_fn)
    result = router.match(method, path)  # -> (handler, params, permission)
"""
import re
from typing import Callable, Optional, Tuple, Dict, List

class Route:
    def __init__(self, method, pattern, handler, permission="ReadOnly"):
        self.method = method
        self.handler = handler
        self.permission = permission
        regex_pattern = re.sub(r'\{(\w+)\}', r'(?P<\1>[a-zA-Z0-9\\\-_.]+)', pattern)
        self.regex = re.compile(f"^{regex_pattern}$")

    def match(self, method, path):
        if self.method != method: return None
        m = self.regex.match(path)
        return m.groupdict() if m else None

class Router:
    def __init__(self):
        self.routes: List[Route] = []

    def add(self, method, pattern, handler, permission="ReadOnly"):
        self.routes.append(Route(method, pattern, handler, permission))

    def get(self, pattern, handler, permission="ReadOnly"): self.add("GET", pattern, handler, permission)
    def post(self, pattern, handler, permission="ReadOnly"): self.add("POST", pattern, handler, permission)
    def put(self, pattern, handler, permission="ReadOnly"): self.add("PUT", pattern, handler, permission)
    def delete(self, pattern, handler, permission="ReadOnly"): self.add("DELETE", pattern, handler, permission)

    def match(self, method, path) -> Optional[Tuple[Callable, Dict[str, str], str]]:
        for route in self.routes:
            params = route.match(method, path)
            if params is not None:
                return (route.handler, params, route.permission)
        return None
