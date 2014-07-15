echo "Trying valid user on unallowed resource."
curl -u policia:password -X GET 'http://localhost:9000/v1/cap/transaction/1'
echo ""
echo "Trying invalid user."
curl -u policia2:password -X GET 'http://localhost:9000/v1/cap/' -i
echo ""
echo "Trying transaction. Checking entities."
curl -u dev:password -X GET 'http://localhost:9000/v1/cap/transaction/1' 
echo ""
echo "Test root resource"
curl -u policia:password -X GET 'http://localhost:9000/v1/cap/test' -i
