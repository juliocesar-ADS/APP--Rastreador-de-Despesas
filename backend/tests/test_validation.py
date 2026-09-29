from datetime import time, timedelta

from backend.app.api.validation import format_time_value


def test_format_time_value_normalizes_mysql_timedelta():
    assert format_time_value(timedelta(hours=9, minutes=15)) == "09:15:00"
    assert format_time_value(time(9, 15)) == "09:15:00"
    assert format_time_value("9:15:00") == "09:15:00"
