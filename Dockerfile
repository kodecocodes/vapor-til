FROM swift:5.2

WORKDIR /package
COPY . ./
CMD ["swift", "test"]
