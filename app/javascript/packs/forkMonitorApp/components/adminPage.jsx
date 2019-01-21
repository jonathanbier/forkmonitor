import React from 'react';

import { Admin, Resource, EditGuesser } from 'react-admin';
import { NodeList, NodeEdit, NodeCreate } from './nodesAdmin';
import jsonServerProvider from 'ra-data-json-server';

class AdminPage extends React.Component {
  constructor(props) {
    super(props);

    this.dataProvider = jsonServerProvider('/api/v1');
  }

  render() {
    return(
      <Admin dataProvider={this.dataProvider}>
        <Resource name="nodes" list={NodeList} edit={NodeEdit}  create={NodeCreate} />
      </Admin>
    );
  }
}

export default AdminPage
