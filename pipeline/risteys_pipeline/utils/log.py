import logging
from os import getenv


class ColoredFormatter(logging.Formatter):
    def format(self, record):
        red = 31
        yellow = 33
        blue = 34
        white = 37
        gray = 90

        def in_color(text, ansi_code):
            """Color the log level using ANSI codes"""
            return f"\033[1;{ansi_code}m{text}\033[0m"

        if record.levelno >= logging.ERROR:
            log_level = in_color("%(levelname)-8s", red)
        elif record.levelno == logging.WARNING:
            log_level = in_color("%(levelname)-8s", yellow)
        elif record.levelno == logging.INFO:
            log_level = in_color("%(levelname)-8s", white)
        else:
            log_level = "%(levelname)-8s"

        when = in_color("%(asctime)s", gray)
        where = in_color("%(module)s:%(funcName)s:%(lineno)d", gray)
        fmt = f"{when} {log_level} %(message)s {where}"
        formatter = logging.Formatter(fmt)
        return formatter.format(record)


logger = logging.getLogger(__name__)

level = getenv("LOG_LEVEL", logging.INFO)
handler = logging.StreamHandler()

handler.setFormatter(ColoredFormatter())
logger.addHandler(handler)
logger.setLevel(level)
