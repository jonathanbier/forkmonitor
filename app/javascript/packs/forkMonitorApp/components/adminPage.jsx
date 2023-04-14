import React from 'react';

import { Admin, Resource, EditGuesser, fetchUtils } from 'react-admin';
import { NodeList, NodeEdit, NodeCreate } from './nodesAdmin';
import { BlockList } from './blocksAdmin';
import { InvalidBlockList, InvalidBlockEdit } from './invalidBlocksAdmin';
import { InflatedBlockList, InflatedBlockEdit } from './inflatedBlocksAdmin';
import authProvider from './authProvider';
import simpleRestProvider from 'ra-data-simple-rest';

const httpClient = (url, options = {}) => {
    if (!options.headers) {
        options.headers = new Headers({ Accept: 'application/json' });
    }
    const token = localStorage.getItem('token');
    options.headers.set('Authorization', `Bearer ${token}`);
    return fetchUtils.fetchJson(url, options);
}

const dataProvider = simpleRestProvider('/api/v1', httpClient);

class AdminPage extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return(
      <Admin dataProvider={dataProvider} authProvider={authProvider}>
        <Resource name="nodes" list={NodeList} edit={NodeEdit}  create={NodeCreate} />
        <Resource name="blocks" list={BlockList} />
        <Resource name="invalid_blocks/admin" list={InvalidBlockList} edit={InvalidBlockEdit} />
        <Resource name="inflated_blocks/admin" list={InflatedBlockList} edit={InflatedBlockEdit} />
      </Admin>
    );
  }
}

export default AdminPage
