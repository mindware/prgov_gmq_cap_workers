echo "Test"
curl -u user:password -X GET 'http://localhost:9000/v1/cap/test'
echo ""
echo "API info"
curl -u user:password -X GET 'http://localhost:9000/v1/cap/'
echo ""
echo "Get users"
curl -u user:password -X GET 'http://localhost:9000/v1/cap/users' -i
echo ""
