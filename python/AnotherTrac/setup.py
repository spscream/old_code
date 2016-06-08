from setuptools import find_packages, setup

version='0.0'

setup(name='AnotherTracPlugin',
      version=version,
      description="This plugin is intended to create a new ticket in \"another_trac\" when it is necessary assign ticket to \"another_trac_user\" in trac.",
      author='Alexander Malaev',
      author_email='amalaev@begun.ru',
      url='',
      keywords='trac plugin',
      license="",
      packages=find_packages(exclude=['ez_setup', 'examples', 'tests*']),
      include_package_data=True,
      package_data={ 'anothertrac': ['templates/*', 'htdocs/*'] },
      zip_safe=False,
      entry_points = """
      [trac.plugins]
      anothertrac.core = anothertrac.core
      anothertrac.db = anothertrac.db
      """,
      )

