import React, { useEffect } from "react";
import ReactGA from "react-ga";

export const withTracker = (WrappedComponent, options = {}, extraProps = {}) => {

  if (process.env['GOOGLE_ANALYTICS']) {
    ReactGA.initialize(process.env['GOOGLE_ANALYTICS']);
  }

  const trackPage = page => {
    ReactGA.set({
      page,
      ...options
    });
    ReactGA.pageview(page);
  };

  const HOC = props => {
    if (process.env['GOOGLE_ANALYTICS']) {
      useEffect(() => trackPage(props.location.pathname), [
        props.location.pathname
      ]);
    }

    return <WrappedComponent {...props} {...extraProps} />;
  };

  return HOC;
};

export default withTracker;
