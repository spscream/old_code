from setuptools import find_packages, setup

version='0.0'

setup(name='AuthCrowd',
      version=version,
      description="Plugin provides atlassian crowd integration",
      author='Alexander Malaev',
      author_email='amalaev@begun.ru',
      url='http://www.spscream.org',
      keywords='trac plugin',
      license="",
      packages=find_packages(exclude=['ez_setup', 'examples', 'tests*']),
      include_package_data=True,
      package_data={ 'authcrowd': ['templates/*', 'htdocs/*'] },
      zip_safe=False,
      entry_points = """
      [trac.plugins]
      authcrowd.crowd_store = authcrowd.crowd_store
      """,
      )

