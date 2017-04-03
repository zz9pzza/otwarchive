#!/bin/bash
grep -C10 "Unpermitted parameters: " log/test.log > /tmp/problem
cat /tmp/problem
test "$(cat /tmp/problem|wc -l)" = "0"
