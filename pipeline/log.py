import logging

logger = logging.getLogger("pipeline")

handler = logging.StreamHandler()

formatter = logging.Formatter(
    "%(asctime)s %(levelname)-5s %(module)s:%(funcName)s:%(message)s",
    "%H:%M:%S"
)
handler.setFormatter(formatter)

logger.addHandler(handler)
logger.setLevel(logging.DEBUG)
